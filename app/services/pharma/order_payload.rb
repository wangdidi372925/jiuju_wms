# frozen_string_literal: true

module Pharma
  class OrderPayload
    def initialize(order, allocations: nil, fulfillments: nil, summary: false)
      @order = order
      @allocations = allocations
      @fulfillments = fulfillments
      @summary = summary
    end

    def as_json
      payload = base_payload.merge(
        allocation_statuses: allocation_statuses,
        fulfillment_statuses: fulfillment_statuses
      )
      return payload if summary

      payload.merge(
        items: ordered_line_items.map { |line_item| item_payload(line_item) },
        allocations: order_allocations.map { |allocation| allocation_payload(allocation) },
        fulfillments: order_fulfillments.map { |fulfillment| fulfillment_payload(fulfillment) }
      )
    end

    private

    attr_reader :order, :summary

    def base_payload
      {
        id: order.id,
        number: order.number,
        email: order.email,
        state: order.state,
        status: order.status,
        item_count: order.item_count,
        item_total: order.item_total.to_s,
        total: order.total.to_s,
        completed_at: iso8601_or_nil(order.completed_at),
        created_at: order.created_at.iso8601,
        updated_at: order.updated_at.iso8601,
        pharmacy: pharmacy_payload
      }
    end

    def pharmacy_payload
      {
        id: metadata_value(order_metadata, 'pharmacy_id'),
        code: metadata_value(order_metadata, 'pharmacy_code'),
        name: metadata_value(order_metadata, 'pharmacy_name')
      }
    end

    def item_payload(line_item)
      metadata = line_item.private_metadata || {}

      {
        id: line_item.id,
        drug_master_id: metadata_value(metadata, 'drug_master_id'),
        drug_name: metadata_value(metadata, 'drug_name'),
        supplier_offer_id: metadata_value(metadata, 'supplier_offer_id'),
        drug_batch_stock_id: metadata_value(metadata, 'drug_batch_stock_id'),
        supplier_display: supplier_display_for(metadata),
        batch_no: metadata_value(metadata, 'batch_no'),
        expiry_date: metadata_value(metadata, 'expiry_date'),
        quantity: line_item.quantity,
        unit_price: line_item.price.to_s,
        total: (line_item.price * line_item.quantity).to_s
      }
    end

    def allocation_payload(allocation)
      {
        id: allocation.id,
        spree_order_id: allocation.spree_order_id,
        spree_line_item_id: allocation.spree_line_item_id,
        supplier_id: allocation.supplier_id,
        supplier_name: allocation.supplier_name_snapshot,
        supplier_warehouse_id: allocation.supplier_warehouse_id,
        supplier_offer_id: allocation.supplier_offer_id,
        drug_batch_stock_id: allocation.drug_batch_stock_id,
        batch_no: allocation.batch_no_snapshot,
        expiry_date: allocation.expiry_date_snapshot.iso8601,
        allocated_unit_price: allocation.allocated_unit_price.to_s,
        allocated_quantity: allocation.allocated_quantity,
        allocated_total: allocation.total_amount.to_s,
        status: allocation.status
      }
    end

    def fulfillment_payload(fulfillment)
      {
        id: fulfillment.id,
        spree_order_id: fulfillment.spree_order_id,
        supplier_id: fulfillment.supplier_id,
        supplier_name: fulfillment.supplier.name,
        supplier_warehouse_id: fulfillment.supplier_warehouse_id,
        warehouse_name: fulfillment.supplier_warehouse.name,
        fulfillment_no: fulfillment.fulfillment_no,
        status: fulfillment.status,
        delivery_company: fulfillment.delivery_company,
        delivery_tracking_no: fulfillment.delivery_tracking_no,
        shipped_at: iso8601_or_nil(fulfillment.shipped_at),
        received_at: iso8601_or_nil(fulfillment.received_at),
        created_at: fulfillment.created_at.iso8601,
        updated_at: fulfillment.updated_at.iso8601
      }
    end

    def supplier_display_for(metadata)
      supplier = Pharma::Supplier.find_by(id: metadata_value(metadata, 'supplier_id'))
      warehouse = Pharma::SupplierWarehouse.find_by(id: metadata_value(metadata, 'supplier_warehouse_id'))
      return {} if supplier.blank? || warehouse.blank?

      config = Pharma::SupplierVisibilityConfig.current
      Pharma::SupplierVisibilityPolicy.new(mode: config.mode).present(supplier: supplier, warehouse: warehouse)
    end

    def allocation_statuses
      order_allocations.map(&:status).uniq
    end

    def fulfillment_statuses
      order_fulfillments.map(&:status).uniq
    end

    def ordered_line_items
      @ordered_line_items ||= order.line_items.order(created_at: :asc)
    end

    def order_allocations
      @order_allocations ||= Array(@allocations || Pharma::OrderAllocation.
        where(spree_order_id: order.id).
        order(created_at: :asc))
    end

    def order_fulfillments
      @order_fulfillments ||= Array(@fulfillments || Pharma::SupplierFulfillment.
        includes(:supplier, :supplier_warehouse).
        where(spree_order_id: order.id).
        order(created_at: :asc))
    end

    def order_metadata
      @order_metadata ||= order.private_metadata || {}
    end

    def metadata_value(metadata, key)
      metadata[key] || metadata[key.to_sym]
    end

    def iso8601_or_nil(value)
      value&.iso8601
    end
  end
end
