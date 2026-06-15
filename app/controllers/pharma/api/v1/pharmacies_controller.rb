# frozen_string_literal: true

module Pharma
  module Api
    module V1
      class PharmaciesController < BaseController
        def create
          pharmacy = Pharma::Pharmacy.create!(pharmacy_params.merge(status: 'pending'))

          render json: { data: pharmacy_payload(pharmacy) }, status: :created
        end

        private

        def pharmacy_params
          params.permit(:name, :code, :contact_name, :contact_phone, :province, :city, :district, :address)
        end

        def pharmacy_payload(pharmacy)
          {
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
        end
      end
    end
  end
end
