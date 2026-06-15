# frozen_string_literal: true

module Pharma
  class Pharmacy < ApplicationRecord
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

    validates :name, :code, :contact_name, :contact_phone, :province, :city, :address, presence: true
    validates :code, uniqueness: true
    validates :status, inclusion: { in: statuses.keys }

    def purchasing_enabled?
      approved? && pharmacy_licenses.any?(&:effective?)
    end
  end
end
