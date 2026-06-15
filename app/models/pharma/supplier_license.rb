# frozen_string_literal: true

module Pharma
  class SupplierLicense < ApplicationRecord
    STATUSES = %w[pending approved rejected expired].freeze

    enum :status, {
      pending: 'pending',
      approved: 'approved',
      rejected: 'rejected',
      expired: 'expired'
    }

    belongs_to :supplier,
               class_name: 'Pharma::Supplier',
               inverse_of: :supplier_licenses

    validates :license_type, :license_no, :status, :starts_on, :expires_on, presence: true
    validates :license_no, uniqueness: { scope: %i[supplier_id license_type] }
    validates :status, inclusion: { in: STATUSES }
    validate :expires_after_start

    def effective?(on: Date.current)
      approved? && starts_on.present? && expires_on.present? && starts_on <= on && expires_on >= on
    end

    private

    def expires_after_start
      return if starts_on.blank? || expires_on.blank?

      errors.add(:expires_on, 'must be on or after starts_on') if expires_on < starts_on
    end
  end
end
