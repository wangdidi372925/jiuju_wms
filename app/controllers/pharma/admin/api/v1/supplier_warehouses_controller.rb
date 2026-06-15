# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class SupplierWarehousesController < BaseController
          def create
            supplier = Pharma::Supplier.find(params[:supplier_id])
            warehouse = supplier.supplier_warehouses.create!(supplier_warehouse_params)

            render json: { data: supplier_warehouse_payload(warehouse) }, status: :created
          end

          def update
            warehouse = Pharma::SupplierWarehouse.find(params[:id])
            warehouse.update!(supplier_warehouse_params)

            render json: { data: supplier_warehouse_payload(warehouse) }
          end

          private

          def supplier_warehouse_params
            params.permit(
              :name,
              :code,
              :province,
              :city,
              :district,
              :address,
              :cold_chain_enabled,
              :status
            )
          end

          def supplier_warehouse_payload(warehouse)
            {
              id: warehouse.id,
              supplier_id: warehouse.supplier_id,
              name: warehouse.name,
              code: warehouse.code,
              province: warehouse.province,
              city: warehouse.city,
              district: warehouse.district,
              address: warehouse.address,
              cold_chain_enabled: warehouse.cold_chain_enabled,
              status: warehouse.status,
              region_label: warehouse.region_label
            }
          end
        end
      end
    end
  end
end
