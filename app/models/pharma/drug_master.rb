# frozen_string_literal: true

module Pharma
  class DrugMaster < ApplicationRecord
    TEMPERATURE_CONTROLS = %w[normal cool cold_chain].freeze
    STATUSES = %w[active inactive].freeze

    has_many :drug_variant_links,
             class_name: 'Pharma::DrugVariantLink',
             dependent: :destroy,
             inverse_of: :drug_master
    has_many :supplier_offers,
             class_name: 'Pharma::SupplierOffer',
             dependent: :restrict_with_error,
             inverse_of: :drug_master
    has_many :drug_batch_stocks,
             class_name: 'Pharma::DrugBatchStock',
             dependent: :restrict_with_error,
             inverse_of: :drug_master

    validates :common_name, :specification, :dosage_form, :manufacturer, :approval_number,
              :package_unit, :storage_condition, :temperature_control, :status, presence: true
    validates :temperature_control, inclusion: { in: TEMPERATURE_CONTROLS }
    validates :status, inclusion: { in: STATUSES }

    def display_name
      [common_name, specification, manufacturer].join(' ')
    end
  end
end
