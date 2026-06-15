# frozen_string_literal: true

module Pharma
  module Ops
    class SessionsController < ApplicationController
      layout 'pharma_ops'

      def new; end

      def create
        token = params[:token].to_s
        client = Pharma::AdminApiClient.find_active_by_token(token) || development_admin_client_for(token)
        return render_invalid_token if client.blank?

        session[:pharma_admin_token] = token
        redirect_to '/pharma/ops', notice: "已登录：#{client.name}"
      end

      def destroy
        session.delete(:pharma_admin_token)
        redirect_to '/pharma/ops/login', notice: '已退出运营后台'
      end

      private

      def development_admin_client_for(token)
        expected = ENV['PHARMA_ADMIN_API_TOKEN'].presence || ('dev-admin-token' unless Rails.env.production?)
        return if expected.blank?
        return unless ActiveSupport::SecurityUtils.secure_compare(token, expected)

        Pharma::AdminApiClient.development_client
      end

      def render_invalid_token
        flash.now[:alert] = '后台 token 无效'
        render :new, status: :unauthorized
      end
    end
  end
end
