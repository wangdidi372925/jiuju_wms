# frozen_string_literal: true

module Pharma
  module Ops
    class CatalogController < BaseController
      def index
        @offers = Pharma::SupplierOffer.
                  includes(:supplier, :supplier_warehouse, :drug_master, :supplier_offer_regions, :drug_batch_stocks).
                  order(updated_at: :desc).
                  limit(100)
      end
    end
  end
end
