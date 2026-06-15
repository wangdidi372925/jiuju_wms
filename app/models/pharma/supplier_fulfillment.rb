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

    def shipped?
      shipped_at.present?
    end

    def received?
      received_at.present?
    end
  end
end
