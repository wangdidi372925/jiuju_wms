# frozen_string_literal: true

module Pharma
  module Api
    module V1
      class OrdersController < BaseController
        DEFAULT_LIMIT = 50
        MAX_LIMIT = 100

        def index
          pharmacy = pharmacy_from_request!
          orders = submitted_orders_for(pharmacy)
          orders = orders.where(status: params[:status]) if params[:status].present?

          render json: {
            data: orders.order(completed_at: :desc, created_at: :desc).limit(limit_value).map do |order|
              Pharma::OrderPayload.new(order, summary: true).as_json
            end
          }
        end

        def show
          pharmacy = pharmacy_from_request!
          order = submitted_orders_for(pharmacy).find_by!(number: params[:number])

          render json: { data: Pharma::OrderPayload.new(order).as_json }
        end

        private

        def submitted_orders_for(pharmacy)
          Spree::Order.
            where.not(completed_at: nil).
            where(
              'spree_orders.private_metadata @> ?',
              {
                source: 'pharma',
                pharmacy_id: pharmacy.id,
                pharmacy_code: pharmacy.code
              }.to_json
            )
        end

        def limit_value
          raw_limit = Integer(params[:limit], exception: false)
          return DEFAULT_LIMIT if raw_limit.blank? || raw_limit <= 0

          [raw_limit, MAX_LIMIT].min
        end
      end
    end
  end
end
