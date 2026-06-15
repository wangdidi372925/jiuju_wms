# frozen_string_literal: true

module Pharma
  class AdminPermissionPolicy
    FULFILLMENT_CONTROLLERS = %w[
      pharma/admin/api/v1/orders
      pharma/admin/api/v1/order_allocations
      pharma/admin/api/v1/supplier_fulfillments
    ].freeze

    READ_METHODS = %w[GET HEAD].freeze

    def initialize(client:, request_method:, controller_path:, action_name:)
      @client = client
      @request_method = request_method.to_s.upcase
      @controller_path = controller_path
      @action_name = action_name
    end

    def allowed?
      return true if role == 'super_admin'
      return true if role == 'operations'
      return read_request? if role == 'viewer'

      fulfillment_allowed?
    end

    private

    attr_reader :client, :request_method, :controller_path, :action_name

    def role
      client&.role.to_s
    end

    def read_request?
      READ_METHODS.include?(request_method)
    end

    def fulfillment_allowed?
      return false unless role == 'fulfillment'
      return false unless FULFILLMENT_CONTROLLERS.include?(controller_path)

      read_request? || (controller_path.end_with?('/supplier_fulfillments') && action_name == 'transition')
    end
  end
end
