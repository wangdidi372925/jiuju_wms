# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class OrdersController < BaseController
          DEFAULT_LIMIT = 50
          MAX_LIMIT = 100

          def index
            orders = filtered_orders

            render json: {
              data: orders.order(completed_at: :desc, created_at: :desc).limit(limit_value).map do |order|
                Pharma::OrderPayload.new(order, summary: true).as_json
              end
            }
          end

          def show
            order = pharma_orders.find_by!(number: params[:number])

            render json: { data: Pharma::OrderPayload.new(order).as_json }
          end

          private

          def filtered_orders
            orders = pharma_orders
            orders = orders.where(status: params[:status]) if params[:status].present?
            orders = orders.where(number: params[:number]) if params[:number].present?
            if params[:pharmacy_code].present?
              orders = orders.where(
                'spree_orders.private_metadata @> ?',
                { pharmacy_code: params[:pharmacy_code] }.to_json
              )
            end
            orders
          end

          def pharma_orders
            Spree::Order.
              where.not(completed_at: nil).
              where('spree_orders.private_metadata @> ?', { source: 'pharma' }.to_json)
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
end
