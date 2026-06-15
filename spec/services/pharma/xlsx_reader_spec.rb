# frozen_string_literal: true

require 'rails_helper'
require 'support/pharma_xlsx_fixture'

RSpec.describe Pharma::XlsxReader do
  include PharmaXlsxFixture

  it 'reads rows from the first worksheet' do
    file = build_xlsx([
                        ['供应商编码', '供应商名称', '单价'],
                        ['SUP-XLSX-001', '华东医药供货有限公司', '8.5']
                      ])

    expect(described_class.new(file.path).rows).to eq(
      [
        ['供应商编码', '供应商名称', '单价'],
        ['SUP-XLSX-001', '华东医药供货有限公司', '8.5']
      ]
    )
  ensure
    file&.close!
  end

  it 'raises a parse error for invalid workbook files' do
    file = Tempfile.new(['invalid', '.xlsx'])
    file.write('not a zip workbook')
    file.rewind

    expect { described_class.new(file.path).rows }.
      to raise_error(Pharma::XlsxReader::ParseError)
  ensure
    file&.close!
  end
end
