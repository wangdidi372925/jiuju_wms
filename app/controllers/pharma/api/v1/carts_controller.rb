# frozen_string_literal: true

module Pharma
  module Api
    module V1
      class CartsController < BaseController
        rescue_from Pharma::PharmacyCartService::CartError, with: :render_cart_error
        rescue_from Pharma::OrderAllocator::AllocationError, with: :render_allocation_error

        def create
          pharmacy = pharmacy_from_request!
          order = cart_service.create_cart(
            pharmacy_code: pharmacy.code,
            email: params[:email]
          )

          render json: { data: cart_payload(order) }, status: :created
        end

        def show
          pharmacy = pharmacy_from_request!
          order = Spree::Order.find_by!(number: params[:number])
          ensure_cart_owner!(order, pharmacy)

          render json: { data: cart_payload(order) }
        end

        def add_item
          pharmacy = pharmacy_from_request!
          line_item = cart_service.add_item(
            order_number: params[:number],
            pharmacy_code: pharmacy.code,
            drug_master_id: params[:drug_master_id],
            quantity: params[:quantity],
            province: params[:province],
            city: params[:city]
          )

          render json: { data: cart_payload(line_item.order.reload) }, status: :created
        end

        def checkout
          pharmacy = pharmacy_from_request!
          result = cart_service.checkout(
            order_number: params[:number],
            pharmacy_code: pharmacy.code
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
          Pharma::OrderPayload.new(order, allocations: allocations, fulfillments: fulfillments).as_json
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
