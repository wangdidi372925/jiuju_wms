# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharma::InventoryImport, type: :model do
  it 'defaults to pending with zero row counters and empty error details' do
    import = described_class.create!(original_filename: 'inventory.xlsx')

    expect(import).to have_attributes(
      status: 'pending',
      total_rows: 0,
      success_rows: 0,
      failed_rows: 0,
      error_details: []
    )
  end
end
