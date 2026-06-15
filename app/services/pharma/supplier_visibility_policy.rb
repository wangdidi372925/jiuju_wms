# frozen_string_literal: true

module Pharma
  class SupplierVisibilityPolicy
    VALID_MODES = %w[hidden partial visible].freeze

    def initialize(mode:)
      raise ArgumentError, "未知的货盘方显示模式：#{mode}" unless VALID_MODES.include?(mode)

      @mode = mode
    end

    def present(supplier:, warehouse:)
      case mode
      when 'hidden'
        hidden_payload
      when 'partial'
        partial_payload(warehouse)
      when 'visible'
        visible_payload(supplier)
      end
    end

    private

    attr_reader :mode

    def hidden_payload
      {
        mode: mode,
        supplier_visible: false,
        supplier_name: nil,
        label: '平台优选'
      }
    end

    def partial_payload(warehouse)
      {
        mode: mode,
        supplier_visible: false,
        supplier_name: nil,
        label: warehouse.region_label
      }
    end

    def visible_payload(supplier)
      {
        mode: mode,
        supplier_visible: true,
        supplier_name: supplier.name,
        label: supplier.name
      }
    end
  end
end
