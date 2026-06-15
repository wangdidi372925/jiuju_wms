# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class PharmaciesController < BaseController
          REVIEW_STATUSES = %w[approved rejected suspended].freeze

          def index
            pharmacies = Pharma::Pharmacy.includes(:pharmacy_licenses).order(created_at: :desc)
            pharmacies = pharmacies.where(status: params[:status]) if params[:status].present?

            render json: { data: pharmacies.map { |pharmacy| pharmacy_payload(pharmacy) } }
          end

          def show
            pharmacy = Pharma::Pharmacy.includes(:pharmacy_licenses).find(params[:id])

            render json: { data: pharmacy_payload(pharmacy, include_licenses: true) }
          end

          def review
            return render_error(:unprocessable_entity, 'invalid_status', '状态无效') unless REVIEW_STATUSES.include?(params[:status])

            pharmacy = Pharma::Pharmacy.find(params[:id])
            pharmacy.update!(status: params[:status])

            render json: { data: pharmacy_payload(pharmacy, include_licenses: true) }
          end

          private

          def pharmacy_payload(pharmacy, include_licenses: false)
            payload = {
              id: pharmacy.id,
              name: pharmacy.name,
              code: pharmacy.code,
              contact_name: pharmacy.contact_name,
              contact_phone: pharmacy.contact_phone,
              province: pharmacy.province,
              city: pharmacy.city,
              district: pharmacy.district,
              address: pharmacy.address,
              status: pharmacy.status,
              purchasing_enabled: pharmacy.purchasing_enabled?
            }
            payload[:licenses] = pharmacy.pharmacy_licenses.map { |license| license_payload(license) } if include_licenses
            payload
          end

          def license_payload(license)
            {
              id: license.id,
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
