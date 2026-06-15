# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class SupplierFulfillmentsController < BaseController
          DEFAULT_LIMIT = 50

          rescue_from Pharma::SupplierFulfillmentWorkflow::WorkflowError, with: :render_workflow_error

          def index
            fulfillments = Pharma::SupplierFulfillment.includes(:supplier, :supplier_warehouse).
                           order(created_at: :desc).
                           limit(DEFAULT_LIMIT)
            fulfillments = fulfillments.where(status: params[:status]) if params[:status].present?

            render json: { data: fulfillments.map { |fulfillment| fulfillment_payload(fulfillment) } }
          end

          def show
            fulfillment = Pharma::SupplierFulfillment.find(params[:id])

            render json: { data: fulfillment_payload(fulfillment, include_allocations: true) }
          end

          def transition
            fulfillment = Pharma::SupplierFulfillment.find(params[:id])
            Pharma::SupplierFulfillmentWorkflow.new.call(
              fulfillment: fulfillment,
              event: params[:event],
              delivery_company: params[:delivery_company],
              delivery_tracking_no: params[:delivery_tracking_no]
            )

            render json: { data: fulfillment_payload(fulfillment.reload, include_allocations: true) }
          end

          private

          def fulfillment_payload(fulfillment, include_allocations: false)
            payload = {
              id: fulfillment.id,
              spree_order_id: fulfillment.spree_order_id,
              supplier_id: fulfillment.supplier_id,
              supplier_name: fulfillment.supplier.name,
              supplier_warehouse_id: fulfillment.supplier_warehouse_id,
              warehouse_name: fulfillment.supplier_warehouse.name,
              fulfillment_no: fulfillment.fulfillment_no,
              status: fulfillment.status,
              delivery_company: fulfillment.delivery_company,
              delivery_tracking_no: fulfillment.delivery_tracking_no,
              shipped_at: iso8601_or_nil(fulfillment.shipped_at),
              received_at: iso8601_or_nil(fulfillment.received_at),
              created_at: fulfillment.created_at.iso8601,
              updated_at: fulfillment.updated_at.iso8601
            }
            payload[:allocations] = related_allocations(fulfillment).map { |allocation| allocation_payload(allocation) } if include_allocations
            payload
          end

          def related_allocations(fulfillment)
            Pharma::OrderAllocation.includes(:drug_batch_stock).
              where(
                spree_order_id: fulfillment.spree_order_id,
                supplier_id: fulfillment.supplier_id,
                supplier_warehouse_id: fulfillment.supplier_warehouse_id
              ).
              order(created_at: :asc)
          end

          def allocation_payload(allocation)
            {
              id: allocation.id,
              spree_order_id: allocation.spree_order_id,
              spree_line_item_id: allocation.spree_line_item_id,
              supplier_offer_id: allocation.supplier_offer_id,
              drug_batch_stock_id: allocation.drug_batch_stock_id,
              batch_no: allocation.batch_no_snapshot,
              expiry_date: allocation.expiry_date_snapshot.iso8601,
              allocated_unit_price: allocation.allocated_unit_price.to_s,
              allocated_quantity: allocation.allocated_quantity,
              status: allocation.status
            }
          end

          def iso8601_or_nil(value)
            value&.iso8601
          end

          def render_workflow_error(error)
            render_error(:unprocessable_entity, error.code, error.message)
          end
        end
      end
    end
  end
end
