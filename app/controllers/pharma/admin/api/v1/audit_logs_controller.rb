# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class AuditLogsController < BaseController
          DEFAULT_LIMIT = 50
          MAX_LIMIT = 200

          def index
            logs = filtered_logs.order(occurred_at: :desc, id: :desc).limit(limit_value)

            render json: {
              data: logs.map { |audit_log| audit_log_payload(audit_log) },
              meta: {
                limit: limit_value,
                count: logs.size
              }
            }
          end

          def show
            audit_log = Pharma::AdminAuditLog.find(params[:id])

            render json: { data: audit_log_payload(audit_log) }
          end

          private

          def filtered_logs
            logs = Pharma::AdminAuditLog.includes(:admin_api_client)
            logs = logs.where(actor_role: params[:actor_role]) if params[:actor_role].present?
            logs = logs.where(status: params[:status]) if params[:status].present?
            logs = logs.where(error_code: params[:error_code]) if params[:error_code].present?
            logs = logs.where(request_method: params[:request_method].to_s.upcase) if params[:request_method].present?
            logs = logs.where('path ILIKE ?', "%#{path_query}%") if path_query.present?
            logs = logs.where(occurred_at: occurred_from..) if occurred_from.present?
            logs = logs.where(occurred_at: ..occurred_to) if occurred_to.present?
            logs
          end

          def audit_log_payload(audit_log)
            {
              id: audit_log.id,
              admin_api_client_id: audit_log.admin_api_client_id,
              actor_name: audit_log.actor_name,
              actor_role: audit_log.actor_role,
              request_method: audit_log.request_method,
              path: audit_log.path,
              controller_path: audit_log.controller_path,
              action_name: audit_log.action_name,
              status: audit_log.status,
              error_code: audit_log.error_code,
              request_params: audit_log.request_params,
              ip_address: audit_log.ip_address,
              user_agent: audit_log.user_agent,
              occurred_at: audit_log.occurred_at.iso8601,
              created_at: audit_log.created_at.iso8601
            }
          end

          def path_query
            @path_query ||= Pharma::AdminAuditLog.sanitize_sql_like(params[:path_query].to_s.strip)
          end

          def occurred_from
            @occurred_from ||= parse_time_param(params[:occurred_from])
          end

          def occurred_to
            @occurred_to ||= parse_time_param(params[:occurred_to])
          end

          def parse_time_param(value)
            return if value.blank?

            Time.zone.parse(value.to_s)
          rescue ArgumentError
            nil
          end

          def limit_value
            raw_limit = Integer(params[:limit], exception: false)
            return DEFAULT_LIMIT if raw_limit.blank? || raw_limit <= 0

            [raw_limit, MAX_LIMIT].min
          end
        end
      end
    end
  end
end
