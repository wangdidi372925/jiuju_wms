# frozen_string_literal: true

RSpec.describe 'Pharma party models', type: :model do
  describe Pharma::Pharmacy do
    def build_pharmacy(status:, license_status: :approved, starts_on: 1.day.ago.to_date, expires_on: 1.day.from_now.to_date)
      described_class.create!(
        name: '久久药房',
        code: "PH-#{SecureRandom.hex(4)}",
        contact_name: '王药师',
        contact_phone: '13800000000',
        province: '浙江省',
        city: '杭州市',
        district: '西湖区',
        address: '文三路 100 号',
        status: status
      ).tap do |pharmacy|
        next unless license_status

        pharmacy.pharmacy_licenses.create!(
          license_type: 'drug_business_license',
          license_no: "浙药营-#{SecureRandom.hex(4)}",
          status: license_status,
          starts_on: starts_on,
          expires_on: expires_on
        )
      end
    end

    it 'enables purchasing only when approved with an effective approved license' do
      aggregate_failures do
        expect(build_pharmacy(status: :approved)).to be_purchasing_enabled

        %i[pending suspended rejected].each do |status|
          expect(build_pharmacy(status: status)).not_to be_purchasing_enabled
        end

        expect(build_pharmacy(status: :approved, license_status: nil)).not_to be_purchasing_enabled

        %i[pending rejected expired].each do |license_status|
          expect(build_pharmacy(status: :approved, license_status: license_status)).not_to be_purchasing_enabled
        end

        expect(build_pharmacy(status: :approved, starts_on: 2.days.ago.to_date, expires_on: 1.day.ago.to_date))
          .not_to be_purchasing_enabled
        expect(build_pharmacy(status: :approved, starts_on: 1.day.from_now.to_date, expires_on: 2.days.from_now.to_date))
          .not_to be_purchasing_enabled
      end
    end
  end

  describe Pharma::Supplier do
    def build_supplier(status:, license_status: :approved, starts_on: 1.day.ago.to_date, expires_on: 1.day.from_now.to_date)
      described_class.create!(
        name: '杭州医药供应有限公司',
        code: "SUP-#{SecureRandom.hex(4)}",
        contact_name: '李经理',
        contact_phone: '13900000000',
        province: '浙江省',
        city: '杭州市',
        status: status,
        priority: 10
      ).tap do |supplier|
        next unless license_status

        supplier.supplier_licenses.create!(
          license_type: 'drug_distribution_license',
          license_no: "浙药供-#{SecureRandom.hex(4)}",
          status: license_status,
          starts_on: starts_on,
          expires_on: expires_on
        )
      end
    end

    it 'is active for offers only when approved with an effective approved license' do
      aggregate_failures do
        expect(build_supplier(status: :approved)).to be_active_for_offers

        %i[pending suspended rejected].each do |status|
          expect(build_supplier(status: status)).not_to be_active_for_offers
        end

        expect(build_supplier(status: :approved, license_status: nil)).not_to be_active_for_offers

        %i[pending rejected expired].each do |license_status|
          expect(build_supplier(status: :approved, license_status: license_status)).not_to be_active_for_offers
        end

        expect(build_supplier(status: :approved, starts_on: 2.days.ago.to_date, expires_on: 1.day.ago.to_date))
          .not_to be_active_for_offers
        expect(build_supplier(status: :approved, starts_on: 1.day.from_now.to_date, expires_on: 2.days.from_now.to_date))
          .not_to be_active_for_offers
      end
    end
  end

  describe Pharma::SupplierVisibilityConfig do
    it 'defaults current mode to hidden' do
      expect(described_class.current.mode).to eq('hidden')
    end
  end
end
