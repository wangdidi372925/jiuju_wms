# frozen_string_literal: true

module Pharma
  class Pharmacy < ApplicationRecord
    STATUSES = %w[pending approved suspended rejected].freeze

    enum :status, {
      pending: 'pending',
      approved: 'approved',
      suspended: 'suspended',
      rejected: 'rejected'
    }

    has_many :pharmacy_licenses,
             class_name: 'Pharma::PharmacyLicense',
             dependent: :destroy,
             inverse_of: :pharmacy
    has_many :pharmacy_users,
             class_name: 'Pharma::PharmacyUser',
             dependent: :destroy,
             inverse_of: :pharmacy

    validates :name, :code, :contact_name, :contact_phone, :province, :city, :address, presence: true
    validates :code, uniqueness: true
    validates :status, inclusion: { in: STATUSES }

    def purchasing_enabled?
      approved? && pharmacy_licenses.any?(&:effective?)
    end
  end
end
