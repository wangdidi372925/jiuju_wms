# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma buyer portal flow', type: :request do
  def approved_pharmacy(code: 'PH-PORTAL-001')
    Pharma::Pharmacy.create!(
      name: '九州一号药店',
      code: code,
      contact_name: '王店长',
      contact_phone: '13800017001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 17 号',
      status: 'approved'
    ).tap do |pharmacy|
      Pharma::PharmacyLicense.create!(
        pharmacy: pharmacy,
        license_type: 'drug_business_license',
        license_no: "#{code}-LICENSE",
        status: 'approved',
        starts_on: Date.current - 1.day,
        expires_on: Date.current + 1.year
      )
    end
  end

  def bind_buyer(pharmacy)
    user = Spree::User.create!(
      email: 'portal-buyer@example.com',
      password: 'Password123!',
      password_confirmation: 'Password123!'
    )
    Pharma::PharmacyUser.create!(
      pharmacy: pharmacy,
      user: user,
      role: 'buyer',
      status: 'active'
    )
  end

  def approved_supplier
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-PORTAL-001',
      contact_name: '李经理',
      contact_phone: '13900017001',
      province: '上海市',
      city: '上海市',
      status: 'approved',
      priority: 10
    ).tap do |supplier|
      Pharma::SupplierLicense.create!(
        supplier: supplier,
        license_type: 'drug_wholesale_license',
        license_no: 'SUP-PORTAL-LICENSE-001',
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
      code: 'WH-PORTAL-001',
      province: '上海市',
      city: '上海市',
      address: '仓库路 17 号',
      status: 'active'
    )
  end

  def drug
    Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字HPORTAL001',
      package_unit: '盒',
      storage_condition: '常温',
      temperature_control: 'normal'
    )
  end

  def offer_for(supplier:, warehouse:, drug:)
    Pharma::SupplierOffer.create!(
      supplier: supplier,
      drug_master: drug,
      supplier_warehouse: warehouse,
      unit_price: 8.5,
      min_order_quantity: 1,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    ).tap do |offer|
      Pharma::SupplierOfferRegion.create!(
        supplier_offer: offer,
        province: '上海市',
        city: '上海市',
        delivery_days: 1,
        status: 'active'
      )
    end
  end

  def stock_setup
    supplier = approved_supplier
    warehouse = warehouse_for(supplier)
    drug = drug()
    offer = offer_for(supplier: supplier, warehouse: warehouse, drug: drug)
    stock = Pharma::DrugBatchStock.create!(
      supplier: supplier,
      supplier_warehouse: warehouse,
      drug_master: drug,
      supplier_offer: offer,
      batch_no: 'BATCH-PORTAL-001',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: 100,
      quantity_locked: 0,
      status: 'active'
    )

    { drug: drug, stock: stock }
  end

  def login_as_buyer(pharmacy)
    bind_buyer(pharmacy)

    post '/pharma/portal/session',
         params: {
           email: 'portal-buyer@example.com',
           password: 'Password123!',
           pharmacy_code: pharmacy.code
         }
  end

  it 'lets a pharmacy buyer search, add to cart, and checkout' do
    pharmacy = approved_pharmacy
    setup = stock_setup

    get '/pharma/portal/login'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('药店登录')

    login_as_buyer(pharmacy)
    expect(response).to redirect_to('/pharma/portal/drugs')

    get '/pharma/portal/drugs',
        params: { query: '阿莫西林', quantity: 10, province: '上海市', city: '上海市' }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('阿莫西林胶囊')
    expect(response.body).to include('8.5')

    post '/pharma/portal/cart/items',
         params: {
           drug_master_id: setup.fetch(:drug).id,
           quantity: 10,
           province: '上海市',
           city: '上海市'
         }

    expect(response).to redirect_to('/pharma/portal/cart')

    get '/pharma/portal/cart'
    expect(response.body).to include('阿莫西林胶囊')
    expect(response.body).to include('85.0')

    post '/pharma/portal/cart/checkout'
    order = Spree::Order.order(:created_at).last

    expect(response).to redirect_to("/pharma/portal/orders/#{order.number}")
    expect(order.reload.status).to eq('placed')
    expect(setup.fetch(:stock).reload.quantity_locked).to eq(10)
  end

  it 'lets a pharmacy buyer confirm receipt for a shipped order' do
    pharmacy = approved_pharmacy(code: 'PH-PORTAL-RECEIVE')
    setup = stock_setup
    login_as_buyer(pharmacy)

    post '/pharma/portal/cart/items',
         params: {
           drug_master_id: setup.fetch(:drug).id,
           quantity: 10,
           province: '上海市',
           city: '上海市'
         }
    post '/pharma/portal/cart/checkout'

    order = Spree::Order.order(:created_at).last
    fulfillment = Pharma::SupplierFulfillment.find_by!(spree_order_id: order.id)
    Pharma::SupplierFulfillmentWorkflow.new.call(
      fulfillment: fulfillment,
      event: 'ship',
      delivery_company: '顺丰速运',
      delivery_tracking_no: 'SFPORTAL001'
    )

    patch "/pharma/portal/orders/#{order.number}/receive"

    expect(response).to redirect_to("/pharma/portal/orders/#{order.number}")
    expect(fulfillment.reload.status).to eq('received')
    expect(order.reload.private_metadata).to include('pharma_order_status' => 'completed')
    expect(setup.fetch(:stock).reload).to have_attributes(
      quantity_on_hand: 90,
      quantity_locked: 0
    )
  end
end
