# frozen_string_literal: true

module Pharma
  module Portal
    class DrugsController < BaseController
      DEFAULT_LIMIT = 30

      def index
        @query = params[:query].to_s.strip
        @quantity = normalized_quantity
        @province = params[:province].presence || current_pharmacy.province
        @city = params[:city].presence || current_pharmacy.city
        @drugs = drug_scope.limit(DEFAULT_LIMIT)
        @offers_by_drug_id = offers_by_drug_id
      end

      private

      def drug_scope
        scope = Pharma::DrugMaster.where(status: 'active').order(updated_at: :desc)
        return scope if @query.blank?

        scope.where(
          <<~SQL.squish,
            common_name ILIKE :query
            OR trade_name ILIKE :query
            OR specification ILIKE :query
            OR manufacturer ILIKE :query
            OR approval_number ILIKE :query
          SQL
          query: "%#{Pharma::DrugMaster.sanitize_sql_like(@query)}%"
        )
      end

      def offers_by_drug_id
        @drugs.to_h do |drug|
          [drug.id, Pharma::OfferMatcher.new.call(
            drug_master: drug,
            pharmacy: current_pharmacy,
            quantity: @quantity,
            province: @province,
            city: @city
          )]
        end
      end

      def normalized_quantity
        quantity = Integer(params[:quantity], exception: false).to_i
        quantity.positive? ? quantity : 1
      end
    end
  end
end
