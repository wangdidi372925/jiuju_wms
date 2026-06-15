# frozen_string_literal: true

require 'securerandom'

module Pharma
  class PharmacyCartService
    Result = Struct.new(:order, :allocations, :fulfillments, keyword_init: true)

    class CartError < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    def create_cart(pharmacy_code:, email: nil)
      pharmacy = purchasable_pharmacy!(pharmacy_code)
      store = Spree::Store.default

      Spree::Order.create!(
        number: next_order_number,
        email: email.presence || "pharmacy-#{pharmacy.id}@pharma.local",
        store: store,
        currency: store.default_currency,
        locale: store.default_locale,
        state: 'cart',
        status: 'draft',
        private_metadata: pharmacy_metadata(pharmacy)
      )
    end

    def add_item(params)
      order_number = params.fetch(:order_number)
      pharmacy_code = params.fetch(:pharmacy_code)
      drug_master_id = params.fetch(:drug_master_id)
      quantity = params.fetch(:quantity)
      province = params.fetch(:province)
      city = params[:city]
      normalized_quantity = normalize_quantity(quantity)
      raise CartError.new('invalid_quantity', 'quantity must be greater than 0') unless normalized_quantity.positive?
      raise CartError.new('missing_province', 'province is required') if province.blank?

      pharmacy = purchasable_pharmacy!(pharmacy_code)
      order = open_cart!(order_number, pharmacy)
      drug = Pharma::DrugMaster.find_by!(id: drug_master_id, status: 'active')
      offer = best_offer_for(
        drug: drug,
        pharmacy: pharmacy,
        quantity: normalized_quantity,
        province: province,
        city: city
      )
      stock = best_stock_for(offer, quantity: normalized_quantity)

      ActiveRecord::Base.transaction do
        variant = variant_for(drug, offer: offer)
        line_item = create_line_item!(
          {
            order: order,
            variant: variant,
            drug: drug,
            offer: offer,
            stock: stock,
            quantity: normalized_quantity
          }
        )
        refresh_order_totals!(order)
        line_item
      end
    end

    def checkout(order_number:, pharmacy_code:)
      pharmacy = purchasable_pharmacy!(pharmacy_code)
      order = open_cart!(order_number, pharmacy)

      ActiveRecord::Base.transaction do
        order.lock!
        line_items = order.line_items.reload.to_a
        raise CartError.new('empty_cart', 'cart must contain at least one item') if line_items.empty?

        allocations = []
        fulfillments = []

        line_items.each do |line_item|
          result = allocate_line_item!(order, line_item)
          allocations << result.allocation
          fulfillments << result.fulfillment
        end

        refresh_order_totals!(order)
        order.update!(
          state: 'complete',
          status: 'placed',
          completed_at: Time.current
        )

        Result.new(order: order, allocations: allocations, fulfillments: fulfillments.uniq)
      end
    end

    private

    def purchasable_pharmacy!(code)
      pharmacy = Pharma::Pharmacy.find_by!(code: code)
      return pharmacy if pharmacy.purchasing_enabled?

      raise CartError.new('pharmacy_not_allowed', 'pharmacy is not allowed to purchase')
    end

    def open_cart!(order_number, pharmacy)
      order = Spree::Order.find_by!(number: order_number)
      raise CartError.new('cart_owner_mismatch', 'cart does not belong to pharmacy') unless cart_belongs_to?(order, pharmacy)
      raise CartError.new('cart_not_open', 'cart has already been submitted') if order.completed_at.present? || order.status == 'placed'

      order
    end

    def cart_belongs_to?(order, pharmacy)
      metadata = order.private_metadata || {}

      metadata['pharmacy_id'].to_i == pharmacy.id && metadata['pharmacy_code'].to_s == pharmacy.code
    end

    def best_offer_for(drug:, pharmacy:, quantity:, province:, city:)
      offer = Pharma::OfferMatcher.new.call(
        drug_master: drug,
        pharmacy: pharmacy,
        quantity: quantity,
        province: province,
        city: city.presence
      ).first
      return offer if offer.present?

      raise CartError.new('offer_unavailable', 'no available offer for the requested drug and quantity')
    end

    def best_stock_for(offer, quantity:)
      stock = offer.drug_batch_stocks.
              select { |batch| batch.available?(min_expiry_date: minimum_expiry_date) && batch.available_quantity >= quantity }.
              max_by(&:expiry_date)
      return stock if stock.present?

      raise CartError.new('offer_unavailable', 'no single batch has enough available stock')
    end

    def create_line_item!(context)
      order = context.fetch(:order)
      variant = context.fetch(:variant)
      offer = context.fetch(:offer)
      quantity = context.fetch(:quantity)

      result = Spree::LineItem.insert!(
        {
          order_id: order.id,
          variant_id: variant.id,
          quantity: quantity,
          price: offer.unit_price,
          currency: order.currency,
          private_metadata: line_item_metadata(
            drug: context.fetch(:drug),
            offer: offer,
            stock: context.fetch(:stock)
          ),
          created_at: Time.current,
          updated_at: Time.current
        },
        returning: %w[id]
      )

      Spree::LineItem.find(result.rows.first.first)
    end

    def variant_for(drug, offer:)
      link = Pharma::DrugVariantLink.find_by(drug_master: drug)
      return link.variant if link.present?

      product = create_spree_product_for(drug, offer: offer)
      Pharma::DrugVariantLink.create!(drug_master: drug, variant: product.master)
      product.master
    end

    def create_spree_product_for(drug, offer:)
      store = Spree::Store.default
      Spree::Product.create!(
        name: drug.display_name,
        slug: "drug-#{drug.approval_number.parameterize.presence || drug.id}",
        status: 'active',
        available_on: Time.current,
        store: store,
        shipping_category: default_shipping_category,
        price: offer.unit_price,
        sku: "DRUG-#{drug.id}",
        public_metadata: {
          pharma_drug_master_id: drug.id,
          approval_number: drug.approval_number
        }
      )
    end

    def default_shipping_category
      Spree::ShippingCategory.first || Spree::ShippingCategory.create!(name: 'Pharma Default')
    end

    def allocate_line_item!(order, line_item)
      metadata = line_item.private_metadata || {}
      supplier_offer_id = metadata['supplier_offer_id']
      stock_id = metadata['drug_batch_stock_id']
      raise CartError.new('cart_item_invalid', 'cart item is missing allocation metadata') if supplier_offer_id.blank? || stock_id.blank?

      Pharma::OrderAllocator.new.call(
        spree_order_id: order.id,
        spree_line_item_id: line_item.id,
        supplier_offer_id: supplier_offer_id,
        drug_batch_stock_id: stock_id,
        quantity: line_item.quantity
      )
    end

    def refresh_order_totals!(order)
      line_items = order.line_items.reload
      item_total = line_items.sum { |line_item| line_item.price * line_item.quantity }

      order.update!(
        item_count: line_items.sum(&:quantity),
        item_total: item_total,
        total: item_total
      )
    end

    def pharmacy_metadata(pharmacy)
      {
        pharmacy_id: pharmacy.id,
        pharmacy_code: pharmacy.code,
        pharmacy_name: pharmacy.name,
        source: 'pharma'
      }
    end

    def line_item_metadata(drug:, offer:, stock:)
      {
        drug_master_id: drug.id,
        drug_name: drug.display_name,
        supplier_offer_id: offer.id,
        drug_batch_stock_id: stock.id,
        supplier_id: offer.supplier_id,
        supplier_name: offer.supplier.name,
        supplier_warehouse_id: offer.supplier_warehouse_id,
        warehouse_name: offer.supplier_warehouse.name,
        batch_no: stock.batch_no,
        expiry_date: stock.expiry_date.iso8601
      }
    end

    def normalize_quantity(quantity)
      Integer(quantity, exception: false).to_i
    end

    def next_order_number
      loop do
        number = "PH#{Time.current.strftime('%Y%m%d')}#{SecureRandom.hex(4).upcase}"
        return number unless Spree::Order.exists?(number: number)
      end
    end

    def minimum_expiry_date
      Pharma::OfferMatcher::DEFAULT_MIN_EXPIRY_DAYS.days.from_now.to_date
    end
  end
end
