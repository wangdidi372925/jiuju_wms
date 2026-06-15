# frozen_string_literal: true

module Pharma
  class SupplierVisibilityConfig < ApplicationRecord
    MODES = %w[hidden partial visible].freeze

    enum :mode, {
      hidden: 'hidden',
      partial: 'partial',
      visible: 'visible'
    }

    validates :mode, presence: true, inclusion: { in: MODES }
    validates :active, uniqueness: true, if: :active?

    def self.current
      find_or_create_by!(active: true) do |config|
        config.mode = :hidden
      end
    end
  end
end
