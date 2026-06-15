# frozen_string_literal: true

module Pharma
  class OrderAllocation < ApplicationRecord
    STATUSES = %w[allocated confirmed canceled fulfilled].freeze

    belongs_to :supplier
    belongs_to :supplier_warehouse
    belongs_to :supplier_offer
    belongs_to :drug_batch_stock
    belongs_to :spree_order, class_name: 'Spree::Order', foreign_key: :spree_order_id, inverse_of: false, optional: true
    belongs_to :spree_line_item,
               class_name: 'Spree::LineItem',
               foreign_key: :spree_line_item_id,
               inverse_of: false,
               optional: true

    validates :spree_order_id, :spree_line_item_id, :supplier_name_snapshot, :batch_no_snapshot,
              :expiry_date_snapshot, :allocated_unit_price, :allocated_quantity, :status, presence: true
    validates :allocated_unit_price, numericality: { greater_than_or_equal_to: 0 }
    validates :allocated_quantity, numericality: { only_integer: true, greater_than: 0 }
    validates :status, inclusion: { in: STATUSES }
    validate :matches_drug_batch_stock
    validate :spree_line_item_belongs_to_order

    def total_amount
      allocated_unit_price * allocated_quantity
    end

    private

    def matches_drug_batch_stock
      return if drug_batch_stock.blank?

      errors.add(:supplier, '必须与批号库存一致') if supplier_id != drug_batch_stock.supplier_id
      errors.add(:supplier_warehouse, '必须与批号库存一致') if supplier_warehouse_id != drug_batch_stock.supplier_warehouse_id
      errors.add(:supplier_offer, '必须与批号库存一致') if supplier_offer_id != drug_batch_stock.supplier_offer_id
    end

    def spree_line_item_belongs_to_order
      return if spree_order_id.blank? || spree_line_item_id.blank?

      if spree_order.blank?
        errors.add(:spree_order, '不存在')
        return
      end

      if spree_line_item.blank?
        errors.add(:spree_line_item, '不存在')
        return
      end

      errors.add(:spree_line_item, '必须属于该订单') if spree_line_item.order_id != spree_order_id
    end
  end
end
