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

    def total_amount
      allocated_unit_price * allocated_quantity
    end
  end
end
