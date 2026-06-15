# frozen_string_literal: true

module Pharma
  module Api
    module V1
      class DrugsController < BaseController
        DEFAULT_LIMIT = 20

        def index
          drugs = Pharma::DrugMaster.where(status: 'active').order(updated_at: :desc).limit(DEFAULT_LIMIT)
          drugs = drugs.where(search_condition, query: search_pattern) if params[:query].present?

          render json: { data: drugs.map { |drug| drug_payload(drug) } }
        end

        def offers
          drug = Pharma::DrugMaster.find_by!(id: params[:id], status: 'active')
          pharmacy = Pharma::Pharmacy.find_by!(code: params[:pharmacy_code])
          quantity = normalized_quantity
          province = params[:province].to_s.strip

          return render_error(:unprocessable_entity, 'invalid_quantity', '数量必须大于 0') unless quantity.positive?
          return render_error(:unprocessable_entity, 'missing_province', '省份不能为空') if province.blank?
          return render_error(:unprocessable_entity, 'pharmacy_not_allowed', '药店当前不允许采购') unless pharmacy.purchasing_enabled?

          matcher = Pharma::OfferMatcher.new
          offers = matcher.call(
            drug_master: drug,
            pharmacy: pharmacy,
            quantity: quantity,
            province: province,
            city: params[:city].presence
          )

          render json: {
            data: offers.map { |offer| offer_payload(offer, province: province, city: params[:city].presence) }
          }
        end

        private

        def search_condition
          <<~SQL.squish
            common_name ILIKE :query
            OR trade_name ILIKE :query
            OR specification ILIKE :query
            OR manufacturer ILIKE :query
            OR approval_number ILIKE :query
          SQL
        end

        def search_pattern
          "%#{Pharma::DrugMaster.sanitize_sql_like(params[:query].to_s.strip)}%"
        end

        def normalized_quantity
          Integer(params[:quantity], exception: false).to_i
        end

        def drug_payload(drug)
          {
            id: drug.id,
            common_name: drug.common_name,
            trade_name: drug.trade_name,
            specification: drug.specification,
            manufacturer: drug.manufacturer,
            approval_number: drug.approval_number,
            package_unit: drug.package_unit,
            prescription_required: drug.prescription_required,
            temperature_control: drug.temperature_control
          }
        end

        def offer_payload(offer, province:, city:)
          {
            id: offer.id,
            drug_master_id: offer.drug_master_id,
            unit_price: offer.unit_price.to_s,
            min_order_quantity: offer.min_order_quantity,
            max_order_quantity: offer.max_order_quantity,
            available_quantity: offer.available_quantity(min_expiry_date: default_min_expiry_date),
            delivery_days: delivery_days_for(offer, province: province, city: city),
            supplier_display: supplier_display_for(offer)
          }
        end

        def supplier_display_for(offer)
          config = Pharma::SupplierVisibilityConfig.current
          Pharma::SupplierVisibilityPolicy.new(mode: config.mode).present(
            supplier: offer.supplier,
            warehouse: offer.supplier_warehouse
          )
        end

        def delivery_days_for(offer, province:, city:)
          offer.supplier_offer_regions.
            select { |region| region.available_for?(province: province, city: city) }.
            map(&:delivery_days).
            min
        end

        def default_min_expiry_date
          Pharma::OfferMatcher::DEFAULT_MIN_EXPIRY_DAYS.days.from_now.to_date
        end
      end
    end
  end
end
