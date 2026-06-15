# frozen_string_literal: true

module Pharma
  module Portal
    class SessionsController < ApplicationController
      layout 'pharma_portal'

      rescue_from Pharma::PharmacySessionService::SessionError, with: :render_session_error

      def new; end

      def create
        result = Pharma::PharmacySessionService.new.create(
          email: params[:email],
          password: params[:password],
          pharmacy_code: params[:pharmacy_code]
        )
        session[:pharma_pharmacy_user_id] = result.pharmacy_user.id
        session[:pharma_cart_number] = nil

        redirect_to '/pharma/portal/drugs', notice: '登录成功'
      end

      def destroy
        session.delete(:pharma_pharmacy_user_id)
        session.delete(:pharma_cart_number)

        redirect_to '/pharma/portal/login', notice: '已退出登录'
      end

      private

      def render_session_error(error)
        flash.now[:alert] = error.message
        render :new, status: error.status
      end
    end
  end
end
