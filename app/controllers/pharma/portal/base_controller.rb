# frozen_string_literal: true

module Pharma
  module Portal
    class BaseController < ApplicationController
      layout 'pharma_portal'

      before_action :require_pharmacy_user!
      helper_method :current_pharmacy_user, :current_pharmacy, :current_cart

      private

      def require_pharmacy_user!
        return if current_pharmacy_user.present?

        redirect_to '/pharma/portal/login', alert: '请先登录药店账号'
      end

      def current_pharmacy_user
        @current_pharmacy_user ||= Pharma::PharmacyUser.active.includes(:pharmacy, :user).find_by(id: session[:pharma_pharmacy_user_id])
      end

      def current_pharmacy
        current_pharmacy_user&.pharmacy
      end

      def current_cart
        return if session[:pharma_cart_number].blank?

        @current_cart ||= begin
          order = Spree::Order.find_by(number: session[:pharma_cart_number])
          order if order.present? && open_cart_for_current_pharmacy?(order)
        end
      end

      def current_or_create_cart
        current_cart || begin
          order = cart_service.create_cart(
            pharmacy_code: current_pharmacy.code,
            email: current_pharmacy_user.user.email
          )
          session[:pharma_cart_number] = order.number
          @current_cart = order
        end
      end

      def open_cart_for_current_pharmacy?(order)
        metadata = order.private_metadata || {}
        metadata['pharmacy_id'].to_i == current_pharmacy.id &&
          metadata['pharmacy_code'].to_s == current_pharmacy.code &&
          order.completed_at.blank? &&
          order.status == 'draft'
      end

      def cart_service
        @cart_service ||= Pharma::PharmacyCartService.new
      end

      def pharma_orders
        Spree::Order.
          where.not(completed_at: nil).
          where('spree_orders.private_metadata @> ?', { source: 'pharma', pharmacy_code: current_pharmacy.code }.to_json)
      end

      def pharma_order_by_number!(number)
        pharma_orders.find_by!(number: number)
      end
    end
  end
end
