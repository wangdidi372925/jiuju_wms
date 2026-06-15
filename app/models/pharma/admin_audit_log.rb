# frozen_string_literal: true

module Pharma
  class AdminAuditLog < ApplicationRecord
    belongs_to :admin_api_client,
               class_name: 'Pharma::AdminApiClient',
               optional: true,
               inverse_of: :admin_audit_logs

    validates :request_method, :path, :controller_path, :action_name, :status, :occurred_at, presence: true
    validates :status, numericality: { only_integer: true, greater_than_or_equal_to: 100, less_than: 600 }
  end
end
