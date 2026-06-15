# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class SupplierVisibilityConfigsController < BaseController
          def show
            render json: { data: config_payload(current_config) }
          end

          def update
            unless Pharma::SupplierVisibilityConfig::MODES.include?(params[:mode])
              return render_error(:unprocessable_entity, 'invalid_visibility_mode', '显示模式无效')
            end

            config = current_config

            if config.update(mode: params[:mode])
              render json: { data: config_payload(config) }
            else
              render_error(:unprocessable_entity, 'invalid_visibility_mode', config.errors.full_messages.to_sentence)
            end
          end

          private

          def current_config
            Pharma::SupplierVisibilityConfig.current
          end

          def config_payload(config)
            {
              mode: config.mode,
              active: config.active
            }
          end
        end
      end
    end
  end
end
