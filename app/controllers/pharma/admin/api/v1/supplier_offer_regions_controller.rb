# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class SupplierOfferRegionsController < BaseController
          def create
            offer = Pharma::SupplierOffer.find(params[:supplier_offer_id])
            region = offer.supplier_offer_regions.create!(supplier_offer_region_params)

            render json: { data: supplier_offer_region_payload(region) }, status: :created
          end

          def update
            region = Pharma::SupplierOfferRegion.find(params[:id])
            region.update!(supplier_offer_region_params)

            render json: { data: supplier_offer_region_payload(region) }
          end

          private

          def supplier_offer_region_params
            params.permit(:province, :city, :district, :delivery_days, :status)
          end

          def supplier_offer_region_payload(region)
            {
              id: region.id,
              supplier_offer_id: region.supplier_offer_id,
              province: region.province,
              city: region.city,
              district: region.district,
              delivery_days: region.delivery_days,
              status: region.status
            }
          end
        end
      end
    end
  end
end
