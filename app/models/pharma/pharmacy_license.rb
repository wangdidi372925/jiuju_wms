# frozen_string_literal: true

module Pharma
  class PharmacyLicense < ApplicationRecord
    STATUSES = %w[pending approved rejected expired].freeze

    enum :status, {
      pending: 'pending',
      approved: 'approved',
      rejected: 'rejected',
      expired: 'expired'
    }

    belongs_to :pharmacy,
               class_name: 'Pharma::Pharmacy',
               inverse_of: :pharmacy_licenses

    validates :license_type, :license_no, :status, :starts_on, :expires_on, presence: true
    validates :license_no, uniqueness: { scope: %i[pharmacy_id license_type] }
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
