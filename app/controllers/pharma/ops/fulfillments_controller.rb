# frozen_string_literal: true

module Pharma
  module Ops
    class FulfillmentsController < BaseController
      rescue_from Pharma::SupplierFulfillmentWorkflow::WorkflowError, with: :render_workflow_error

      def index
        @status = params[:status].presence
        @fulfillments = Pharma::SupplierFulfillment.includes(:supplier, :supplier_warehouse).order(created_at: :desc).limit(100)
        @fulfillments = @fulfillments.where(status: @status) if @status.present?
      end

      def show
        @fulfillment = Pharma::SupplierFulfillment.includes(:supplier, :supplier_warehouse).find(params[:id])
        @allocations = related_allocations(@fulfillment)
      end

      def transition
        fulfillment = Pharma::SupplierFulfillment.find(params[:id])
        Pharma::SupplierFulfillmentWorkflow.new.call(
          fulfillment: fulfillment,
          event: params[:event],
          delivery_company: params[:delivery_company],
          delivery_tracking_no: params[:delivery_tracking_no]
        )

        redirect_to "/pharma/ops/fulfillments/#{fulfillment.id}", notice: '履约状态已更新'
      end

      private

      def related_allocations(fulfillment)
        Pharma::OrderAllocation.includes(:drug_batch_stock).
          where(
            spree_order_id: fulfillment.spree_order_id,
            supplier_id: fulfillment.supplier_id,
            supplier_warehouse_id: fulfillment.supplier_warehouse_id
          ).
          order(created_at: :asc)
      end

      def render_workflow_error(error)
        redirect_back fallback_location: '/pharma/ops/fulfillments', alert: error.message
      end
    end
  end
end
