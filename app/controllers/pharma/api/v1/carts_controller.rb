# frozen_string_literal: true

module Pharma
  module Api
    module V1
      class CartsController < BaseController
        rescue_from Pharma::PharmacyCartService::CartError, with: :render_cart_error
        rescue_from Pharma::OrderAllocator::AllocationError, with: :render_allocation_error

        def create
          order = cart_service.create_cart(
            pharmacy_code: params[:pharmacy_code],
            email: params[:email]
          )

          render json: { data: cart_payload(order) }, status: :created
        end

        def show
          pharmacy = Pharma::Pharmacy.find_by!(code: params[:pharmacy_code])
          order = Spree::Order.find_by!(number: params[:number])
          ensure_cart_owner!(order, pharmacy)

          render json: { data: cart_payload(order) }
        end

        def add_item
          line_item = cart_service.add_item(
            order_number: params[:number],
            pharmacy_code: params[:pharmacy_code],
            drug_master_id: params[:drug_master_id],
            quantity: params[:quantity],
            province: params[:province],
            city: params[:city]
          )

          render json: { data: cart_payload(line_item.order.reload) }, status: :created
        end

        def checkout
          result = cart_service.checkout(
            order_number: params[:number],
            pharmacy_code: params[:pharmacy_code]
          )

          render json: { data: cart_payload(result.order, allocations: result.allocations, fulfillments: result.fulfillments) }
        end

        private

        def cart_service
          @cart_service ||= Pharma::PharmacyCartService.new
        end

        def ensure_cart_owner!(order, pharmacy)
          metadata = order.private_metadata || {}
          return if metadata['pharmacy_id'].to_i == pharmacy.id && metadata['pharmacy_code'].to_s == pharmacy.code

          raise Pharma::PharmacyCartService::CartError.new('cart_owner_mismatch', '购物车不属于该药店')
        end

        def cart_payload(order, allocations: [], fulfillments: [])
          {
            id: order.id,
            number: order.number,
            email: order.email,
            state: order.state,
            status: order.status,
            item_count: order.item_count,
            item_total: order.item_total.to_s,
            total: order.total.to_s,
            completed_at: iso8601_or_nil(order.completed_at),
            pharmacy: pharmacy_payload(order),
            items: order.line_items.order(created_at: :asc).map { |line_item| item_payload(line_item) },
            allocations: allocations.map { |allocation| allocation_payload(allocation) },
            fulfillments: fulfillments.map { |fulfillment| fulfillment_payload(fulfillment) }
          }
        end

        def pharmacy_payload(order)
          metadata = order.private_metadata || {}
          {
            id: metadata['pharmacy_id'],
            code: metadata['pharmacy_code'],
            name: metadata['pharmacy_name']
          }
        end

        def item_payload(line_item)
          metadata = line_item.private_metadata || {}
          {
            id: line_item.id,
            drug_master_id: metadata['drug_master_id'],
            drug_name: metadata['drug_name'],
            supplier_offer_id: metadata['supplier_offer_id'],
            drug_batch_stock_id: metadata['drug_batch_stock_id'],
            supplier_display: supplier_display_for(metadata),
            batch_no: metadata['batch_no'],
            expiry_date: metadata['expiry_date'],
            quantity: line_item.quantity,
            unit_price: line_item.price.to_s,
            total: (line_item.price * line_item.quantity).to_s
          }
        end

        def supplier_display_for(metadata)
          config = Pharma::SupplierVisibilityConfig.current
          supplier = Pharma::Supplier.find_by(id: metadata['supplier_id'])
          warehouse = Pharma::SupplierWarehouse.find_by(id: metadata['supplier_warehouse_id'])
          return {} if supplier.blank? || warehouse.blank?

          Pharma::SupplierVisibilityPolicy.new(mode: config.mode).present(supplier: supplier, warehouse: warehouse)
        end

        def allocation_payload(allocation)
          {
            id: allocation.id,
            supplier_offer_id: allocation.supplier_offer_id,
            drug_batch_stock_id: allocation.drug_batch_stock_id,
            batch_no: allocation.batch_no_snapshot,
            expiry_date: allocation.expiry_date_snapshot.iso8601,
            allocated_unit_price: allocation.allocated_unit_price.to_s,
            allocated_quantity: allocation.allocated_quantity,
            status: allocation.status
          }
        end

        def fulfillment_payload(fulfillment)
          {
            id: fulfillment.id,
            supplier_id: fulfillment.supplier_id,
            supplier_warehouse_id: fulfillment.supplier_warehouse_id,
            fulfillment_no: fulfillment.fulfillment_no,
            status: fulfillment.status
          }
        end

        def iso8601_or_nil(value)
          value&.iso8601
        end

        def render_cart_error(error)
          render_error(:unprocessable_entity, error.code, error.message)
        end

        def render_allocation_error(error)
          render_error(:unprocessable_entity, error.code, error.message)
        end
      end
    end
  end
end
