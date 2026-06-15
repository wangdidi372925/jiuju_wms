# frozen_string_literal: true

module Pharma
  class DrugBatchStock < ApplicationRecord
    STATUSES = %w[active locked expired recalled].freeze

    belongs_to :supplier,
               class_name: 'Pharma::Supplier'
    belongs_to :supplier_warehouse,
               class_name: 'Pharma::SupplierWarehouse'
    belongs_to :drug_master,
               class_name: 'Pharma::DrugMaster',
               inverse_of: :drug_batch_stocks
    belongs_to :supplier_offer,
               class_name: 'Pharma::SupplierOffer',
               inverse_of: :drug_batch_stocks

    validates :batch_no, :expiry_date, :status, presence: true
    validates :quantity_on_hand, :quantity_locked,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :status, inclusion: { in: STATUSES }
    validate :locked_not_greater_than_on_hand
    validate :matches_supplier_offer

    def available_quantity
      quantity_on_hand - quantity_locked
    end

    def available?(min_expiry_date: Date.current)
      status == 'active' && expiry_date >= min_expiry_date && available_quantity.positive?
    end

    private

    def locked_not_greater_than_on_hand
      return if quantity_on_hand.blank? || quantity_locked.blank?

      errors.add(:quantity_locked, 'cannot exceed quantity_on_hand') if quantity_locked > quantity_on_hand
    end

    def matches_supplier_offer
      return if supplier_offer.blank?

      errors.add(:supplier, 'must match supplier_offer') if supplier_id != supplier_offer.supplier_id
      if supplier_warehouse_id != supplier_offer.supplier_warehouse_id
        errors.add(:supplier_warehouse, 'must match supplier_offer')
      end
      errors.add(:drug_master, 'must match supplier_offer') if drug_master_id != supplier_offer.drug_master_id
    end
  end
end
