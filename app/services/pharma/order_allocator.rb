# frozen_string_literal: true

module Pharma
  class OrderAllocator
    Result = Struct.new(:allocation, :fulfillment, keyword_init: true)

    class AllocationError < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    def call(spree_order_id:, spree_line_item_id:, supplier_offer_id:, drug_batch_stock_id:, quantity:)
      normalized_quantity = normalize_quantity(quantity)

      ActiveRecord::Base.transaction do
        order = Spree::Order.find(spree_order_id)
        line_item = Spree::LineItem.find(spree_line_item_id)
        offer = Pharma::SupplierOffer.find(supplier_offer_id)
        stock = Pharma::DrugBatchStock.find(drug_batch_stock_id)

        ensure_line_item_belongs_to_order!(line_item, order)
        ensure_stock_matches_offer!(stock, offer)
        ensure_offer_allocatable!(offer)

        stock.with_lock do
          ensure_stock_available!(stock, normalized_quantity)
          stock.update!(quantity_locked: stock.quantity_locked + normalized_quantity)
        end

        allocation = create_allocation!(
          order: order,
          line_item: line_item,
          offer: offer,
          stock: stock,
          quantity: normalized_quantity
        )
        fulfillment = find_or_create_fulfillment!(order: order, offer: offer)

        Result.new(allocation: allocation, fulfillment: fulfillment)
      end
    end

    private

    def normalize_quantity(quantity)
      normalized = Integer(quantity, exception: false).to_i
      raise AllocationError.new('invalid_quantity', '数量必须大于 0') unless normalized.positive?

      normalized
    end

    def ensure_line_item_belongs_to_order!(line_item, order)
      return if line_item.order_id == order.id

      raise AllocationError.new('line_item_order_mismatch', '订单明细必须属于该订单')
    end

    def ensure_stock_matches_offer!(stock, offer)
      return if stock.supplier_offer_id == offer.id

      raise AllocationError.new('stock_offer_mismatch', '库存必须属于该货盘报价')
    end

    def ensure_offer_allocatable!(offer)
      return if offer.status == 'approved' &&
        offer.starts_at <= Time.current &&
        offer.ends_at >= Time.current &&
        offer.supplier.active_for_offers? &&
        offer.supplier_warehouse.active?

      raise AllocationError.new('offer_unavailable', '货盘报价当前不可分单')
    end

    def ensure_stock_available!(stock, quantity)
      return if stock.available?(min_expiry_date: minimum_expiry_date) && stock.available_quantity >= quantity

      raise AllocationError.new('insufficient_stock', '可用库存不足')
    end

    def create_allocation!(order:, line_item:, offer:, stock:, quantity:)
      Pharma::OrderAllocation.create!(
        spree_order_id: order.id,
        spree_line_item_id: line_item.id,
        supplier: offer.supplier,
        supplier_warehouse: offer.supplier_warehouse,
        supplier_offer: offer,
        drug_batch_stock: stock,
        supplier_name_snapshot: offer.supplier.name,
        batch_no_snapshot: stock.batch_no,
        expiry_date_snapshot: stock.expiry_date,
        allocated_unit_price: offer.unit_price,
        allocated_quantity: quantity,
        status: 'allocated'
      )
    end

    def find_or_create_fulfillment!(order:, offer:)
      Pharma::SupplierFulfillment.find_or_create_by!(
        spree_order_id: order.id,
        supplier: offer.supplier,
        supplier_warehouse: offer.supplier_warehouse
      ) do |fulfillment|
        fulfillment.fulfillment_no = fulfillment_no_for(order: order, offer: offer)
        fulfillment.status = 'pending'
      end
    end

    def fulfillment_no_for(order:, offer:)
      "FUL-#{order.number}-#{offer.supplier_id}-#{offer.supplier_warehouse_id}"
    end

    def minimum_expiry_date
      Pharma::OfferMatcher::DEFAULT_MIN_EXPIRY_DAYS.days.from_now.to_date
    end
  end
end
