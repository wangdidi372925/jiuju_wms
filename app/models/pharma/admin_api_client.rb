# frozen_string_literal: true

require 'digest'
require 'securerandom'

module Pharma
  class AdminApiClient < ApplicationRecord
    TOKEN_PREFIX = 'adm_'
    ROLES = %w[super_admin operations viewer fulfillment].freeze
    STATUSES = %w[active disabled].freeze

    DevelopmentClient = Struct.new(:id, :name, :role, :status, keyword_init: true) do
      def active?
        status == 'active'
      end
    end

    enum :role, {
      super_admin: 'super_admin',
      operations: 'operations',
      viewer: 'viewer',
      fulfillment: 'fulfillment'
    }
    enum :status, {
      active: 'active',
      disabled: 'disabled'
    }

    has_many :admin_audit_logs,
             class_name: 'Pharma::AdminAuditLog',
             dependent: :nullify,
             inverse_of: :admin_api_client

    validates :name, :token_digest, :token_prefix, :role, :status, presence: true
    validates :token_digest, uniqueness: true
    validates :role, inclusion: { in: ROLES }
    validates :status, inclusion: { in: STATUSES }

    def self.issue!(name:, role:)
      raw_token = "#{TOKEN_PREFIX}#{SecureRandom.urlsafe_base64(32)}"
      client = create!(
        name: name,
        role: role,
        status: 'active',
        token_digest: digest(raw_token),
        token_prefix: raw_token.first(12)
      )

      [client, raw_token]
    end

    def self.find_active_by_token(raw_token)
      return if raw_token.blank?

      client = find_by(token_digest: digest(raw_token))
      return unless client&.active?

      client.touch(:last_used_at)
      client
    end

    def self.development_client
      DevelopmentClient.new(id: nil, name: '开发默认管理员', role: 'super_admin', status: 'active')
    end

    def self.digest(raw_token)
      Digest::SHA256.hexdigest(raw_token.to_s)
    end
  end
end
