# frozen_string_literal: true

module Pharma
  module Ops
    class OrdersController < BaseController
      def index
        @orders = pharma_orders.order(completed_at: :desc, created_at: :desc).limit(100)
      end

      def show
        @order = pharma_orders.find_by!(number: params[:number])
      end

      private

      def pharma_orders
        Spree::Order.where.not(completed_at: nil).where('spree_orders.private_metadata @> ?', { source: 'pharma' }.to_json)
      end
    end
  end
end
