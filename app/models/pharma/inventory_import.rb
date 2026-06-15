# frozen_string_literal: true

module Pharma
  class InventoryImport < ApplicationRecord
    STATUSES = %w[pending completed completed_with_errors failed].freeze

    validates :original_filename, :status, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :total_rows, :success_rows, :failed_rows,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
