# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class DrugBatchStocksController < BaseController
          def create
            stock = Pharma::DrugBatchStock.create!(drug_batch_stock_params)

            render json: { data: drug_batch_stock_payload(stock) }, status: :created
          end

          def update
            stock = Pharma::DrugBatchStock.find(params[:id])
            stock.update!(drug_batch_stock_params)

            render json: { data: drug_batch_stock_payload(stock) }
          end

          private

          def drug_batch_stock_params
            params.permit(
              :supplier_id,
              :supplier_warehouse_id,
              :drug_master_id,
              :supplier_offer_id,
              :batch_no,
              :expiry_date,
              :quantity_on_hand,
              :quantity_locked,
              :status
            )
          end

          def drug_batch_stock_payload(stock)
            {
              id: stock.id,
              supplier_id: stock.supplier_id,
              supplier_warehouse_id: stock.supplier_warehouse_id,
              drug_master_id: stock.drug_master_id,
              supplier_offer_id: stock.supplier_offer_id,
              batch_no: stock.batch_no,
              expiry_date: stock.expiry_date.iso8601,
              quantity_on_hand: stock.quantity_on_hand,
              quantity_locked: stock.quantity_locked,
              available_quantity: stock.available_quantity,
              status: stock.status
            }
          end
        end
      end
    end
  end
end
