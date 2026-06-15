# frozen_string_literal: true

module Pharma
  class OrderCancellationService
    class CancellationError < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    SHIPPED_STATUSES = %w[shipped received].freeze

    def call(order:, actor: nil)
      ActiveRecord::Base.transaction do
        order.lock!
        fulfillments = Pharma::SupplierFulfillment.where(spree_order_id: order.id).order(:id).to_a

        raise CancellationError.new('order_not_cancelable', '订单当前不可取消') if fulfillments.empty?
        if fulfillments.any? { |fulfillment| SHIPPED_STATUSES.include?(fulfillment.status) }
          raise CancellationError.new('order_already_shipped', '订单已有履约单发货，不能取消')
        end

        fulfillments.each do |fulfillment|
          next if fulfillment.status == 'canceled'

          Pharma::SupplierFulfillmentWorkflow.new.call(fulfillment: fulfillment, event: 'cancel')
        end

        order.update_columns(
          status: 'canceled',
          private_metadata: cancellation_metadata(order, actor).merge('pharma_order_status' => 'canceled'),
          updated_at: Time.current
        )
        order
      end
    end

    private

    def cancellation_metadata(order, actor)
      (order.private_metadata || {}).merge(
        canceled_at: Time.current.iso8601,
        canceled_by: actor.to_s.presence || 'system'
      )
    end
  end
end
