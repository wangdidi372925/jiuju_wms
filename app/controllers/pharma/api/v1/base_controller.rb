# frozen_string_literal: true

module Pharma
  module Api
    module V1
      class BaseController < ActionController::API
        rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
        rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

        private

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
