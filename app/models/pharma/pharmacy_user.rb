# frozen_string_literal: true

module Pharma
  class PharmacyUser < ApplicationRecord
    ROLES = %w[owner buyer finance].freeze
    STATUSES = %w[active disabled].freeze

    enum :role, {
      owner: 'owner',
      buyer: 'buyer',
      finance: 'finance'
    }
    enum :status, {
      active: 'active',
      disabled: 'disabled'
    }

    belongs_to :pharmacy, class_name: 'Pharma::Pharmacy', inverse_of: :pharmacy_users
    belongs_to :user, class_name: 'Spree::User', foreign_key: :spree_user_id, inverse_of: false

    has_many :pharmacy_api_tokens,
             class_name: 'Pharma::PharmacyApiToken',
             dependent: :destroy,
             inverse_of: :pharmacy_user

    validates :role, :status, presence: true
    validates :role, inclusion: { in: ROLES }
    validates :status, inclusion: { in: STATUSES }
    validates :spree_user_id, uniqueness: { scope: :pharmacy_id }

    def can_purchase?
      active? && pharmacy.purchasing_enabled?
    end
  end
end
