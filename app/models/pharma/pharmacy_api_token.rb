# frozen_string_literal: true

require 'digest'
require 'securerandom'

module Pharma
  class PharmacyApiToken < ApplicationRecord
    TOKEN_PREFIX = 'pharm_'
    DEFAULT_TTL = 30.days

    belongs_to :pharmacy_user,
               class_name: 'Pharma::PharmacyUser',
               inverse_of: :pharmacy_api_tokens

    validates :token_digest, :token_prefix, presence: true
    validates :token_digest, uniqueness: true

    def self.issue!(pharmacy_user:, expires_at: DEFAULT_TTL.from_now)
      raw_token = "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(32)}"
      token = create!(
        pharmacy_user: pharmacy_user,
        token_digest: digest(raw_token),
        token_prefix: raw_token.first(12),
        expires_at: expires_at
      )

      [token, raw_token]
    end

    def self.find_active_by_token(raw_token)
      return if raw_token.blank?

      token = includes(pharmacy_user: :pharmacy).find_by(token_digest: digest(raw_token))
      return unless token&.active?

      token.touch(:last_used_at)
      token
    end

    def self.digest(raw_token)
      Digest::SHA256.hexdigest(raw_token.to_s)
    end

    def active?
      revoked_at.blank? && !expired? && pharmacy_user.active?
    end

    def expired?
      expires_at.present? && expires_at <= Time.current
    end

    def revoke!
      update!(revoked_at: Time.current)
    end
  end
end
