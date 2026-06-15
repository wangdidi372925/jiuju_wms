# frozen_string_literal: true

module Pharma
  class DrugVariantLink < ApplicationRecord
    belongs_to :drug_master,
               class_name: 'Pharma::DrugMaster',
               inverse_of: :drug_variant_links
    belongs_to :variant,
               class_name: 'Spree::Variant',
               foreign_key: :spree_variant_id,
               inverse_of: false

    validates :spree_variant_id, uniqueness: true
  end
end
