# frozen_string_literal: true

Rails.application.config.to_prepare do
  next unless defined?(Spree::Admin::TaxonsController)

  Spree::Admin::TaxonsController.class_eval do
    unless method_defined?(:redirect_missing_taxonomy)
      prepend_before_action :redirect_missing_taxonomy, only: :index

      private

      def redirect_missing_taxonomy
        redirect_to spree.admin_taxonomies_path unless params[:taxonomy_id].present?
      end
    end
  end
end
