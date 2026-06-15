# frozen_string_literal: true

module Pharma
  class SupplierFulfillment < ApplicationRecord
    STATUSES = %w[pending picking shipped received canceled].freeze

    belongs_to :supplier
    belongs_to :supplier_warehouse
    belongs_to :spree_order, class_name: 'Spree::Order', foreign_key: :spree_order_id, inverse_of: false, optional: true

    validates :spree_order_id, :fulfillment_no, :status, presence: true
    validates :fulfillment_no, uniqueness: true
    validates :status, inclusion: { in: STATUSES }
    validate :warehouse_belongs_to_supplier
    validate :spree_order_exists

    def shipped?
      shipped_at.present?
    end

    def received?
      received_at.present?
    end

    private

    def warehouse_belongs_to_supplier
      return if supplier.blank? || supplier_warehouse.blank?

      errors.add(:supplier_warehouse, 'must belong to supplier') if supplier_warehouse.supplier_id != supplier.id
    end

    def spree_order_exists
      return if spree_order_id.blank?

      errors.add(:spree_order, 'must exist') if spree_order.blank?
    end
  end
end
