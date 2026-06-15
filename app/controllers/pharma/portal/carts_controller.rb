# frozen_string_literal: true

module Pharma
  module Portal
    class CartsController < BaseController
      rescue_from Pharma::PharmacyCartService::CartError, with: :render_cart_error
      rescue_from Pharma::OrderAllocator::AllocationError, with: :render_allocation_error

      def show
        @cart = current_cart
      end

      def add_item
        order = current_or_create_cart
        cart_service.add_item(
          order_number: order.number,
          pharmacy_code: current_pharmacy.code,
          drug_master_id: params[:drug_master_id],
          quantity: params[:quantity],
          province: params[:province],
          city: params[:city]
        )
        @current_cart = order.reload

        redirect_to '/pharma/portal/cart', notice: '已加入购物车'
      end

      def checkout
        return redirect_to('/pharma/portal/cart', alert: '购物车为空') if current_cart.blank?

        result = cart_service.checkout(
          order_number: current_cart.number,
          pharmacy_code: current_pharmacy.code
        )
        session.delete(:pharma_cart_number)

        redirect_to "/pharma/portal/orders/#{result.order.number}", notice: '订单已提交'
      end

      private

      def render_cart_error(error)
        redirect_back fallback_location: '/pharma/portal/cart', alert: error.message
      end

      def render_allocation_error(error)
        redirect_back fallback_location: '/pharma/portal/cart', alert: error.message
      end
    end
  end
end
