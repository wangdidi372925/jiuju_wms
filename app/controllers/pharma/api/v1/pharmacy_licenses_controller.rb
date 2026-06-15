# frozen_string_literal: true

module Pharma
  module Api
    module V1
      class PharmacyLicensesController < BaseController
        def create
          pharmacy = Pharma::Pharmacy.find_by!(code: params[:pharmacy_code])
          license = pharmacy.pharmacy_licenses.create!(license_params.merge(status: 'pending'))

          render json: { data: license_payload(license) }, status: :created
        end

        private

        def license_params
          params.permit(:license_type, :license_no, :starts_on, :expires_on)
        end

        def license_payload(license)
          {
            id: license.id,
            pharmacy_id: license.pharmacy_id,
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
