# frozen_string_literal: true

module Pharma
  class Supplier < ApplicationRecord
    STATUSES = %w[pending approved suspended rejected].freeze

    enum :status, {
      pending: 'pending',
      approved: 'approved',
      suspended: 'suspended',
      rejected: 'rejected'
    }

    has_many :supplier_licenses,
             class_name: 'Pharma::SupplierLicense',
             dependent: :destroy,
             inverse_of: :supplier
    has_many :supplier_warehouses,
             class_name: 'Pharma::SupplierWarehouse',
             dependent: :destroy,
             inverse_of: :supplier

    validates :name, :code, :contact_name, :contact_phone, :province, :city, presence: true
    validates :code, uniqueness: true
    validates :priority, numericality: { only_integer: true }
    validates :status, inclusion: { in: STATUSES }

    def active_for_offers?
      approved? && supplier_licenses.any?(&:effective?)
    end
  end
end
