# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class SupplierOffersController < BaseController
          DEFAULT_LIMIT = 50

          def index
            offers = Pharma::SupplierOffer.includes(:supplier, :drug_master, :supplier_warehouse).
                     order(created_at: :desc).
                     limit(DEFAULT_LIMIT)

            render json: { data: offers.map { |offer| supplier_offer_payload(offer) } }
          end

          def show
            offer = Pharma::SupplierOffer.includes(:supplier_offer_regions, :drug_batch_stocks).find(params[:id])

            render json: { data: supplier_offer_payload(offer, include_children: true) }
          end

          def create
            offer = Pharma::SupplierOffer.create!(supplier_offer_params)

            render json: { data: supplier_offer_payload(offer) }, status: :created
          end

          def update
            offer = Pharma::SupplierOffer.find(params[:id])
            offer.update!(supplier_offer_params)

            render json: { data: supplier_offer_payload(offer) }
          end

          private

          def supplier_offer_params
            params.permit(
              :supplier_id,
              :drug_master_id,
              :supplier_warehouse_id,
              :unit_price,
              :min_order_quantity,
              :max_order_quantity,
              :status,
              :starts_at,
              :ends_at
            )
          end

          def supplier_offer_payload(offer, include_children: false)
            payload = {
              id: offer.id,
              supplier_id: offer.supplier_id,
              drug_master_id: offer.drug_master_id,
              supplier_warehouse_id: offer.supplier_warehouse_id,
              unit_price: offer.unit_price.to_s,
              min_order_quantity: offer.min_order_quantity,
              max_order_quantity: offer.max_order_quantity,
              status: offer.status,
              starts_at: offer.starts_at.iso8601,
              ends_at: offer.ends_at.iso8601
            }

            if include_children
              payload[:regions] = offer.supplier_offer_regions.map { |region| supplier_offer_region_payload(region) }
              payload[:batch_stocks] = offer.drug_batch_stocks.map { |stock| drug_batch_stock_payload(stock) }
            end

            payload
          end

          def supplier_offer_region_payload(region)
            {
              id: region.id,
              province: region.province,
              city: region.city,
              district: region.district,
              delivery_days: region.delivery_days,
              status: region.status
            }
          end

          def drug_batch_stock_payload(stock)
            {
              id: stock.id,
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
