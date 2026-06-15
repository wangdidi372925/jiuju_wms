# frozen_string_literal: true

module Pharma
  class SupplierFulfillmentWorkflow
    class WorkflowError < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    OPEN_STATUSES = %w[pending picking].freeze

    def call(fulfillment:, event:, delivery_company: nil, delivery_tracking_no: nil)
      ActiveRecord::Base.transaction do
        fulfillment.lock!

        case event.to_s
        when 'start_picking'
          start_picking!(fulfillment)
        when 'ship'
          ship!(fulfillment, delivery_company: delivery_company, delivery_tracking_no: delivery_tracking_no)
        when 'receive'
          receive!(fulfillment)
        when 'cancel'
          cancel!(fulfillment)
        else
          raise WorkflowError.new('unsupported_event', '不支持的履约操作')
        end
      end
    end

    private

    def start_picking!(fulfillment)
      ensure_status!(fulfillment, allowed: ['pending'])

      fulfillment.update!(status: 'picking')
      fulfillment
    end

    def ship!(fulfillment, delivery_company:, delivery_tracking_no:)
      ensure_status!(fulfillment, allowed: OPEN_STATUSES)

      fulfillment.update!(
        status: 'shipped',
        delivery_company: delivery_company.presence || fulfillment.delivery_company,
        delivery_tracking_no: delivery_tracking_no.presence || fulfillment.delivery_tracking_no,
        shipped_at: fulfillment.shipped_at || Time.current
      )
      related_allocations(fulfillment).where(status: 'allocated').update_all(status: 'confirmed', updated_at: Time.current)
      fulfillment
    end

    def receive!(fulfillment)
      ensure_status!(fulfillment, allowed: ['shipped'])

      fulfillment.update!(
        status: 'received',
        received_at: fulfillment.received_at || Time.current
      )
      related_allocations(fulfillment).where.not(status: 'canceled').update_all(status: 'fulfilled', updated_at: Time.current)
      fulfillment
    end

    def cancel!(fulfillment)
      ensure_status!(fulfillment, allowed: OPEN_STATUSES)

      allocations = related_allocations(fulfillment).where(status: %w[allocated confirmed])
      release_locked_stock!(allocations)
      allocations.update_all(status: 'canceled', updated_at: Time.current)
      fulfillment.update!(status: 'canceled')
      fulfillment
    end

    def ensure_status!(fulfillment, allowed:)
      return if allowed.include?(fulfillment.status)

      raise WorkflowError.new('invalid_transition', "当前履约状态（#{fulfillment.status}）不允许执行该操作")
    end

    def related_allocations(fulfillment)
      Pharma::OrderAllocation.where(
        spree_order_id: fulfillment.spree_order_id,
        supplier_id: fulfillment.supplier_id,
        supplier_warehouse_id: fulfillment.supplier_warehouse_id
      )
    end

    def release_locked_stock!(allocations)
      allocations.includes(:drug_batch_stock).find_each do |allocation|
        stock = allocation.drug_batch_stock

        stock.with_lock do
          stock.update!(quantity_locked: [stock.quantity_locked - allocation.allocated_quantity, 0].max)
        end
      end
    end
  end
end
