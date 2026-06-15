# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class SuppliersController < BaseController
          DEFAULT_LIMIT = 50

          def index
            suppliers = Pharma::Supplier.order(created_at: :desc).limit(DEFAULT_LIMIT)

            render json: { data: suppliers.map { |supplier| supplier_payload(supplier) } }
          end

          def show
            supplier = Pharma::Supplier.includes(:supplier_licenses, :supplier_warehouses).find(params[:id])

            render json: { data: supplier_payload(supplier, include_children: true) }
          end

          def create
            supplier = Pharma::Supplier.create!(supplier_params)

            render json: { data: supplier_payload(supplier) }, status: :created
          end

          def update
            supplier = Pharma::Supplier.find(params[:id])
            supplier.update!(supplier_params)

            render json: { data: supplier_payload(supplier) }
          end

          private

          def supplier_params
            params.permit(:name, :code, :contact_name, :contact_phone, :province, :city, :status, :priority)
          end

          def supplier_payload(supplier, include_children: false)
            payload = {
              id: supplier.id,
              name: supplier.name,
              code: supplier.code,
              contact_name: supplier.contact_name,
              contact_phone: supplier.contact_phone,
              province: supplier.province,
              city: supplier.city,
              status: supplier.status,
              priority: supplier.priority,
              active_for_offers: supplier.active_for_offers?
            }

            if include_children
              payload[:licenses] = supplier.supplier_licenses.map { |license| supplier_license_payload(license) }
              payload[:warehouses] = supplier.supplier_warehouses.map { |warehouse| supplier_warehouse_payload(warehouse) }
            end

            payload
          end

          def supplier_license_payload(license)
            {
              id: license.id,
              license_type: license.license_type,
              license_no: license.license_no,
              status: license.status,
              starts_on: license.starts_on.iso8601,
              expires_on: license.expires_on.iso8601
            }
          end

          def supplier_warehouse_payload(warehouse)
            {
              id: warehouse.id,
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
