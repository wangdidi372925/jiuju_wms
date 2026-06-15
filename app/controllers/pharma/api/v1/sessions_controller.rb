# frozen_string_literal: true

module Pharma
  module Api
    module V1
      class SessionsController < BaseController
        rescue_from Pharma::PharmacySessionService::SessionError, with: :render_session_error

        def create
          result = Pharma::PharmacySessionService.new.create(
            email: params[:email],
            password: params[:password],
            pharmacy_code: params[:pharmacy_code]
          )

          render json: { data: session_payload(result) }, status: :created
        end

        def destroy
          current_pharmacy_api_token!.revoke!

          render json: { data: { revoked: true } }
        end

        private

        def session_payload(result)
          pharmacy_user = result.pharmacy_user
          token_record = result.token_record

          {
            token: result.raw_token,
            token_type: 'Bearer',
            expires_at: token_record.expires_at&.iso8601,
            pharmacy: pharmacy_payload(pharmacy_user.pharmacy),
            user: user_payload(pharmacy_user)
          }
        end

        def pharmacy_payload(pharmacy)
          {
            id: pharmacy.id,
            code: pharmacy.code,
            name: pharmacy.name,
            status: pharmacy.status,
            purchasing_enabled: pharmacy.purchasing_enabled?
          }
        end

        def user_payload(pharmacy_user)
          {
            id: pharmacy_user.user.id,
            email: pharmacy_user.user.email,
            role: pharmacy_user.role,
            status: pharmacy_user.status
          }
        end

        def render_session_error(error)
          render_error(error.status, error.code, error.message)
        end
      end
    end
  end
end
