# frozen_string_literal: true

module Pharma
  module Ops
    class DashboardController < BaseController
      def show
        @pending_pharmacies_count = Pharma::Pharmacy.where(status: 'pending').count
        @placed_orders_count = pharma_orders.where(status: 'placed').count
        @pending_fulfillments_count = Pharma::SupplierFulfillment.where(status: %w[pending picking]).count
        @low_stock_count = Pharma::DrugBatchStock.where(status: 'active').select { |stock| stock.available_quantity < 20 }.count
      end

      private

      def pharma_orders
        Spree::Order.where.not(completed_at: nil).where('spree_orders.private_metadata @> ?', { source: 'pharma' }.to_json)
      end
    end
  end
end
