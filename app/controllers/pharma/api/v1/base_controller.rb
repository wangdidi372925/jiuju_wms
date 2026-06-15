# frozen_string_literal: true

module Pharma
  module Api
    module V1
      class BaseController < ActionController::API
        class PharmacyAuthError < StandardError
          attr_reader :code

          def initialize(code, message)
            @code = code
            super(message)
          end
        end

        rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
        rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
        rescue_from PharmacyAuthError, with: :render_pharmacy_auth_error

        private

        def pharmacy_from_request!
          return current_pharmacy_api_token!.pharmacy_user.pharmacy if bearer_token.present?
          return Pharma::Pharmacy.find_by!(code: params[:pharmacy_code]) if params[:pharmacy_code].present?

          raise PharmacyAuthError.new('missing_pharmacy_identity', '请先登录药店账号')
        end

        def current_pharmacy_api_token!
          @current_pharmacy_api_token ||= begin
            token = Pharma::PharmacyApiToken.find_active_by_token(bearer_token)
            raise PharmacyAuthError.new('invalid_token', '登录已失效，请重新登录') if token.blank?

            token
          end
        end

        def bearer_token
          authorization = request.headers['Authorization'].to_s
          match = authorization.match(/\ABearer\s+(.+)\z/i)
          match&.[](1)&.strip
        end

        def render_error(status, code, message)
          render json: { error: code, message: message }, status: status
        end

        def render_not_found
          render_error(:not_found, 'not_found', '记录不存在')
        end

        def render_record_invalid(error)
          render_error(:unprocessable_entity, 'validation_failed', error.record.errors.full_messages.to_sentence)
        end

        def render_pharmacy_auth_error(error)
          render_error(:unauthorized, error.code, error.message)
        end
      end
    end
  end
end
