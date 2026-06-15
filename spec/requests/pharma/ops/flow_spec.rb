# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma operations portal flow', type: :request do
  def pending_pharmacy
    Pharma::Pharmacy.create!(
      name: '待审九州药店',
      code: 'PH-OPS-001',
      contact_name: '王店长',
      contact_phone: '13800018001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 18 号',
      status: 'pending'
    )
  end

  def pharmacy_license_for(pharmacy)
    Pharma::PharmacyLicense.create!(
      pharmacy: pharmacy,
      license_type: 'drug_business_license',
      license_no: "#{pharmacy.code}-LICENSE",
      status: 'pending',
      starts_on: Date.current - 1.day,
      expires_on: Date.current + 1.year
    )
  end

  def approved_pharmacy
    pharmacy = pending_pharmacy
    pharmacy.update!(status: 'approved')
    pharmacy_license_for(pharmacy).update!(status: 'approved')
    pharmacy
  end

  def approved_supplier
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-OPS-001',
      contact_name: '李经理',
      contact_phone: '13900018001',
      province: '上海市',
      city: '上海市',
      status: 'approved',
      priority: 10
    ).tap do |supplier|
      Pharma::SupplierLicense.create!(
        supplier: supplier,
        license_type: 'drug_wholesale_license',
        license_no: 'SUP-OPS-LICENSE-001',
        status: 'approved',
        starts_on: Date.current - 1.day,
        expires_on: Date.current + 1.year
      )
    end
  end

  def warehouse_for(supplier)
    Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: '上海中心仓',
      code: 'WH-OPS-001',
      province: '上海市',
      city: '上海市',
      address: '仓库路 18 号',
      status: 'active'
    )
  end

  def stock_setup
    supplier = approved_supplier
    warehouse = warehouse_for(supplier)
    drug = Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字HOPS001',
      package_unit: '盒',
      storage_condition: '常温',
      temperature_control: 'normal'
    )
    offer = Pharma::SupplierOffer.create!(
      supplier: supplier,
      drug_master: drug,
      supplier_warehouse: warehouse,
      unit_price: 8.5,
      min_order_quantity: 1,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    )
    Pharma::SupplierOfferRegion.create!(
      supplier_offer: offer,
      province: '上海市',
      city: '上海市',
      delivery_days: 1,
      status: 'active'
    )
    stock = Pharma::DrugBatchStock.create!(
      supplier: supplier,
      supplier_warehouse: warehouse,
      drug_master: drug,
      supplier_offer: offer,
      batch_no: 'BATCH-OPS-001',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: 100,
      quantity_locked: 0,
      status: 'active'
    )

    { drug: drug, stock: stock, pharmacy: approved_pharmacy }
  end

  def create_order_for(setup)
    user = Spree::User.create!(
      email: 'ops-buyer@example.com',
      password: 'Password123!',
      password_confirmation: 'Password123!'
    )
    Pharma::PharmacyUser.create!(pharmacy: setup.fetch(:pharmacy), user: user, role: 'buyer', status: 'active')
    service = Pharma::PharmacyCartService.new
    order = service.create_cart(pharmacy_code: setup.fetch(:pharmacy).code, email: user.email)
    service.add_item(
      order_number: order.number,
      pharmacy_code: setup.fetch(:pharmacy).code,
      drug_master_id: setup.fetch(:drug).id,
      quantity: 10,
      province: '上海市',
      city: '上海市'
    )
    service.checkout(order_number: order.number, pharmacy_code: setup.fetch(:pharmacy).code).order
  end

  def login_as_ops
    post '/pharma/ops/session', params: { token: 'dev-admin-token' }
  end

  it 'lets operations log in and review a pharmacy with its license' do
    pharmacy = pending_pharmacy
    license = pharmacy_license_for(pharmacy)

    get '/pharma/ops/login'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('运营登录')

    login_as_ops
    expect(response).to redirect_to('/pharma/ops')

    get '/pharma/ops/pharmacies'
    expect(response.body).to include('待审九州药店')

    patch "/pharma/ops/pharmacies/#{pharmacy.id}/review", params: { status: 'approved' }
    expect(response).to redirect_to("/pharma/ops/pharmacies/#{pharmacy.id}")
    expect(pharmacy.reload.status).to eq('approved')

    patch "/pharma/ops/pharmacy_licenses/#{license.id}/review", params: { status: 'approved' }
    expect(response).to redirect_to("/pharma/ops/pharmacies/#{pharmacy.id}")
    expect(license.reload.status).to eq('approved')
    expect(pharmacy.reload).to be_purchasing_enabled
  end

  it 'lets operations inspect catalog and ship a fulfillment' do
    setup = stock_setup
    order = create_order_for(setup)
    fulfillment = Pharma::SupplierFulfillment.find_by!(spree_order_id: order.id)

    login_as_ops

    get '/pharma/ops/catalog'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('阿莫西林胶囊')
    expect(response.body).to include('BATCH-OPS-001')

    get '/pharma/ops/fulfillments'
    expect(response.body).to include(fulfillment.fulfillment_no)

    patch "/pharma/ops/fulfillments/#{fulfillment.id}/transition",
          params: { event: 'ship', delivery_company: '顺丰速运', delivery_tracking_no: 'SFOPS001' }

    expect(response).to redirect_to("/pharma/ops/fulfillments/#{fulfillment.id}")
    expect(fulfillment.reload).to have_attributes(
      status: 'shipped',
      delivery_company: '顺丰速运',
      delivery_tracking_no: 'SFOPS001'
    )
    expect(order.reload.private_metadata).to include('pharma_order_status' => 'shipped')
  end
end
