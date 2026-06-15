# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class BaseController < ActionController::API
          before_action :authenticate_admin_token!
          before_action :authorize_admin_request!
          after_action :record_admin_audit_log

          rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
          rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

          private

          attr_reader :current_admin_api_client

          def authenticate_admin_token!
            @current_admin_api_client = admin_client_from_token
            return if @current_admin_api_client.present?

            render_error(:unauthorized, 'unauthorized', '管理员接口令牌无效')
          end

          def authorize_admin_request!
            return if performed?
            return if Pharma::AdminPermissionPolicy.new(
              client: current_admin_api_client,
              request_method: request.request_method,
              controller_path: controller_path,
              action_name: action_name
            ).allowed?

            render_error(:forbidden, 'forbidden', '当前后台角色无权执行该操作')
          end

          def admin_client_from_token
            provided = request.headers['X-Pharma-Admin-Token'].to_s
            return if provided.blank?

            Pharma::AdminApiClient.find_active_by_token(provided) || development_admin_client_for(provided)
          end

          def development_admin_client_for(provided)
            expected = admin_api_token
            return if expected.blank?
            return unless ActiveSupport::SecurityUtils.secure_compare(provided, expected)

            Pharma::AdminApiClient.development_client
          end

          def admin_api_token
            ENV['PHARMA_ADMIN_API_TOKEN'].presence || ('dev-admin-token' unless Rails.env.production?)
          end

          def render_error(status, code, message)
            render json: { error: code, message: message }, status: status
            @pharma_admin_error_code = code
            record_admin_audit_log
          end

          def render_not_found
            render_error(:not_found, 'not_found', '记录不存在')
          end

          def render_record_invalid(error)
            render_error(:unprocessable_entity, 'validation_failed', error.record.errors.full_messages.to_sentence)
          end

          def record_admin_audit_log
            return if @pharma_admin_audit_recorded

            @pharma_admin_audit_recorded = true
            Pharma::AdminAuditLog.create!(
              admin_api_client: persisted_admin_api_client,
              actor_name: current_admin_api_client&.name,
              actor_role: current_admin_api_client&.role,
              request_method: request.request_method,
              path: request.path,
              controller_path: controller_path,
              action_name: action_name,
              status: response.status,
              error_code: @pharma_admin_error_code,
              request_params: sanitized_request_params,
              ip_address: request.remote_ip,
              user_agent: request.user_agent,
              occurred_at: Time.current
            )
          end

          def persisted_admin_api_client
            current_admin_api_client if current_admin_api_client.is_a?(Pharma::AdminApiClient)
          end

          def sanitized_request_params
            request.filtered_parameters.except('controller', 'action').as_json
          end
        end
      end
    end
  end
end
