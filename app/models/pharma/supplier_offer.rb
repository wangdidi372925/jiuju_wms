# frozen_string_literal: true

module Pharma
  class SupplierOffer < ApplicationRecord
    STATUSES = %w[draft approved suspended expired].freeze

    belongs_to :supplier,
               class_name: 'Pharma::Supplier'
    belongs_to :drug_master,
               class_name: 'Pharma::DrugMaster',
               inverse_of: :supplier_offers
    belongs_to :supplier_warehouse,
               class_name: 'Pharma::SupplierWarehouse'

    has_many :supplier_offer_regions,
             class_name: 'Pharma::SupplierOfferRegion',
             dependent: :destroy,
             inverse_of: :supplier_offer
    has_many :drug_batch_stocks,
             class_name: 'Pharma::DrugBatchStock',
             dependent: :restrict_with_error,
             inverse_of: :supplier_offer

    validates :unit_price, numericality: { greater_than: 0 }
    validates :min_order_quantity, numericality: { only_integer: true, greater_than: 0 }
    validates :max_order_quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :status, :starts_at, :ends_at, presence: true
    validates :status, inclusion: { in: STATUSES }
    validate :ends_after_start
    validate :warehouse_belongs_to_supplier

    def available_for?(province:, city:, quantity:, on: Time.current, min_expiry_date: 180.days.from_now.to_date)
      status == 'approved' &&
        starts_at <= on &&
        ends_at >= on &&
        supplier.active_for_offers? &&
        supplier_warehouse.active? &&
        quantity >= min_order_quantity &&
        within_max_order_quantity?(quantity) &&
        region_available?(province: province, city: city) &&
        available_stock(min_expiry_date: min_expiry_date).sum(&:available_quantity) >= quantity
    end

    def available_quantity(min_expiry_date: Date.current)
      available_stock(min_expiry_date: min_expiry_date).sum(&:available_quantity)
    end

    def best_available_stock(min_expiry_date: Date.current)
      available_stock(min_expiry_date: min_expiry_date).max_by(&:expiry_date)
    end

    private

    def available_stock(min_expiry_date:)
      drug_batch_stocks.select { |stock| stock.available?(min_expiry_date: min_expiry_date) }
    end

    def region_available?(province:, city:)
      supplier_offer_regions.any? { |region| region.available_for?(province: province, city: city) }
    end

    def within_max_order_quantity?(quantity)
      max_order_quantity.blank? || quantity <= max_order_quantity
    end

    def ends_after_start
      return if starts_at.blank? || ends_at.blank?

      errors.add(:ends_at, 'must be after starts_at') if ends_at <= starts_at
    end

    def warehouse_belongs_to_supplier
      return if supplier.blank? || supplier_warehouse.blank?

      errors.add(:supplier_warehouse, 'must belong to supplier') if supplier_warehouse.supplier_id != supplier.id
    end
  end
end
