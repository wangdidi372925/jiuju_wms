# frozen_string_literal: true

module Pharma
  class OrderStatusSync
    def call(order:)
      fulfillments = Pharma::SupplierFulfillment.where(spree_order_id: order.id).to_a
      return order if fulfillments.empty?

      pharma_status = pharma_status_for(fulfillments)
      order.update_columns(
        status: spree_status_for(pharma_status),
        private_metadata: (order.private_metadata || {}).merge('pharma_order_status' => pharma_status),
        updated_at: Time.current
      )
      order
    end

    private

    def pharma_status_for(fulfillments)
      return 'canceled' if fulfillments.all? { |fulfillment| fulfillment.status == 'canceled' }
      return 'completed' if fulfillments.all? { |fulfillment| fulfillment.status == 'received' }
      return 'shipped' if fulfillments.any? { |fulfillment| fulfillment.status == 'shipped' }
      return 'processing' if fulfillments.any? { |fulfillment| fulfillment.status == 'picking' }

      'placed'
    end

    def spree_status_for(pharma_status)
      pharma_status == 'canceled' ? 'canceled' : 'placed'
    end
  end
end
