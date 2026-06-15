# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class BaseController < ActionController::API
          before_action :authenticate_admin_token!

          rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
          rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

          private

          def authenticate_admin_token!
            return if valid_admin_token?

            render_error(:unauthorized, 'unauthorized', 'invalid admin api token')
          end

          def valid_admin_token?
            expected = admin_api_token
            provided = request.headers['X-Pharma-Admin-Token'].to_s

            expected.present? && provided.present? && ActiveSupport::SecurityUtils.secure_compare(provided, expected)
          end

          def admin_api_token
            ENV['PHARMA_ADMIN_API_TOKEN'].presence || ('dev-admin-token' unless Rails.env.production?)
          end

          def render_error(status, code, message)
            render json: { error: code, message: message }, status: status
          end

          def render_not_found
            render_error(:not_found, 'not_found', 'record not found')
          end

          def render_record_invalid(error)
            render_error(:unprocessable_entity, 'validation_failed', error.record.errors.full_messages.to_sentence)
          end
        end
      end
    end
  end
end
