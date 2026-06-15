# frozen_string_literal: true

module Pharma
  module Ops
    class BaseController < ApplicationController
      layout 'pharma_ops'

      before_action :require_admin_client!
      helper_method :current_admin_api_client

      private

      def require_admin_client!
        return if current_admin_api_client.present?

        redirect_to '/pharma/ops/login', alert: '请先登录运营后台'
      end

      def current_admin_api_client
        @current_admin_api_client ||= admin_client_from_session
      end

      def admin_client_from_session
        token = session[:pharma_admin_token].to_s
        return if token.blank?

        Pharma::AdminApiClient.find_active_by_token(token) || development_admin_client_for(token)
      end

      def development_admin_client_for(token)
        expected = ENV['PHARMA_ADMIN_API_TOKEN'].presence || ('dev-admin-token' unless Rails.env.production?)
        return if expected.blank?
        return unless ActiveSupport::SecurityUtils.secure_compare(token, expected)

        Pharma::AdminApiClient.development_client
      end
    end
  end
end
