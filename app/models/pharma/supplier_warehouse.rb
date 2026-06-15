# frozen_string_literal: true

module Pharma
  class SupplierWarehouse < ApplicationRecord
    enum :status, {
      active: 'active',
      suspended: 'suspended',
      closed: 'closed'
    }

    belongs_to :supplier,
               class_name: 'Pharma::Supplier',
               inverse_of: :supplier_warehouses

    validates :name, :code, :province, :city, :address, presence: true
    validates :code, uniqueness: true
    validates :status, inclusion: { in: statuses.keys }

    def region_label
      [province, city, district].compact_blank.join(' / ')
    end
  end
end
