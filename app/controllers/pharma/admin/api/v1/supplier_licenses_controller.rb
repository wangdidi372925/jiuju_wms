# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class SupplierLicensesController < BaseController
          def create
            supplier = Pharma::Supplier.find(params[:supplier_id])
            license = supplier.supplier_licenses.create!(supplier_license_params)

            render json: { data: supplier_license_payload(license) }, status: :created
          end

          def update
            license = Pharma::SupplierLicense.find(params[:id])
            license.update!(supplier_license_params)

            render json: { data: supplier_license_payload(license) }
          end

          private

          def supplier_license_params
            params.permit(:license_type, :license_no, :status, :starts_on, :expires_on)
          end

          def supplier_license_payload(license)
            {
              id: license.id,
              supplier_id: license.supplier_id,
              license_type: license.license_type,
              license_no: license.license_no,
              status: license.status,
              starts_on: license.starts_on.iso8601,
              expires_on: license.expires_on.iso8601
            }
          end
        end
      end
    end
  end
end
