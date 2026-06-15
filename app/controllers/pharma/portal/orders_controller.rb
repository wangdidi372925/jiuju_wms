# frozen_string_literal: true

module Pharma
  module Portal
    class OrdersController < BaseController
      rescue_from Pharma::OrderCancellationService::CancellationError, with: :render_cancellation_error
      rescue_from Pharma::SupplierFulfillmentWorkflow::WorkflowError, with: :render_workflow_error

      def index
        @orders = pharma_orders.order(completed_at: :desc, created_at: :desc).limit(50)
      end

      def show
        @order = pharma_order_by_number!(params[:number])
      end

      def cancel
        order = pharma_order_by_number!(params[:number])
        Pharma::OrderCancellationService.new.call(order: order, actor: 'buyer')

        redirect_to "/pharma/portal/orders/#{order.number}", notice: '订单已取消'
      end

      def receive
        order = pharma_order_by_number!(params[:number])
        fulfillments = Pharma::SupplierFulfillment.where(spree_order_id: order.id, status: 'shipped')
        return redirect_to("/pharma/portal/orders/#{order.number}", alert: '没有待确认收货的履约单') if fulfillments.empty?

        fulfillments.find_each do |fulfillment|
          Pharma::SupplierFulfillmentWorkflow.new.call(fulfillment: fulfillment, event: 'receive')
        end

        redirect_to "/pharma/portal/orders/#{order.number}", notice: '已确认收货'
      end

      private

      def render_cancellation_error(error)
        redirect_back fallback_location: '/pharma/portal/orders', alert: error.message
      end

      def render_workflow_error(error)
        redirect_back fallback_location: '/pharma/portal/orders', alert: error.message
      end
    end
  end
end
