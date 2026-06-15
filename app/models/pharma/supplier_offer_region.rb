# frozen_string_literal: true

module Pharma
  class SupplierOfferRegion < ApplicationRecord
    STATUSES = %w[active suspended].freeze

    belongs_to :supplier_offer,
               class_name: 'Pharma::SupplierOffer',
               inverse_of: :supplier_offer_regions

    validates :province, :delivery_days, :status, presence: true
    validates :delivery_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :status, inclusion: { in: STATUSES }

    def available_for?(province:, city:)
      status == 'active' && self.province == province && (self.city.blank? || self.city == city)
    end
  end
end
