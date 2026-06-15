# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharma::SupplierVisibilityPolicy do
  let(:supplier) do
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-VIS-001',
      contact_name: '李经理',
      contact_phone: '13900000004',
      province: '上海市',
      city: '上海市',
      status: 'approved'
    )
  end

  let(:warehouse) do
    Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: '上海中心仓',
      code: 'WH-VIS-001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '仓库路 3 号',
      status: 'active'
    )
  end

  it 'hides supplier identity in hidden mode' do
    result = described_class.new(mode: 'hidden').present(supplier: supplier, warehouse: warehouse)

    expect(result).to eq(
      mode: 'hidden',
      supplier_visible: false,
      supplier_name: nil,
      label: '平台优选'
    )
  end

  it 'shows regional warehouse label in partial mode' do
    result = described_class.new(mode: 'partial').present(supplier: supplier, warehouse: warehouse)

    expect(result).to eq(
      mode: 'partial',
      supplier_visible: false,
      supplier_name: nil,
      label: '上海市 / 上海市 / 浦东新区'
    )
  end

  it 'shows supplier identity in visible mode' do
    result = described_class.new(mode: 'visible').present(supplier: supplier, warehouse: warehouse)

    expect(result).to eq(
      mode: 'visible',
      supplier_visible: true,
      supplier_name: '华东医药供货有限公司',
      label: '华东医药供货有限公司'
    )
  end

  it 'rejects unknown visibility modes' do
    expect { described_class.new(mode: 'unknown') }.
      to raise_error(ArgumentError, '未知的货盘方显示模式：unknown')
  end
end
