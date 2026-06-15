# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class PharmacyLicensesController < BaseController
          REVIEW_STATUSES = %w[approved rejected expired].freeze

          def review
            return render_error(:unprocessable_entity, 'invalid_status', 'status is invalid') unless REVIEW_STATUSES.include?(params[:status])

            license = Pharma::PharmacyLicense.find(params[:id])
            license.update!(status: params[:status])

            render json: { data: license_payload(license) }
          end

          private

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
end
