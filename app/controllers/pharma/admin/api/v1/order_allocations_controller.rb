# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class OrderAllocationsController < BaseController
          rescue_from Pharma::OrderAllocator::AllocationError, with: :render_allocation_error

          def create
            result = Pharma::OrderAllocator.new.call(
              spree_order_id: params[:spree_order_id],
              spree_line_item_id: params[:spree_line_item_id],
              supplier_offer_id: params[:supplier_offer_id],
              drug_batch_stock_id: params[:drug_batch_stock_id],
              quantity: params[:quantity]
            )

            render json: { data: result_payload(result) }, status: :created
          end

          private

          def result_payload(result)
            {
              allocation: allocation_payload(result.allocation),
              fulfillment: fulfillment_payload(result.fulfillment)
            }
          end

          def allocation_payload(allocation)
            {
              id: allocation.id,
              spree_order_id: allocation.spree_order_id,
              spree_line_item_id: allocation.spree_line_item_id,
              supplier_offer_id: allocation.supplier_offer_id,
              drug_batch_stock_id: allocation.drug_batch_stock_id,
              supplier_name: allocation.supplier_name_snapshot,
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
              spree_order_id: fulfillment.spree_order_id,
              supplier_id: fulfillment.supplier_id,
              supplier_warehouse_id: fulfillment.supplier_warehouse_id,
              fulfillment_no: fulfillment.fulfillment_no,
              status: fulfillment.status
            }
          end

          def render_allocation_error(error)
            render_error(:unprocessable_entity, error.code, error.message)
          end
        end
      end
    end
  end
end
