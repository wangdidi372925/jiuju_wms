# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Localization' do
  it 'uses Simplified Chinese as the default application locale' do
    expect(I18n.default_locale).to eq(:'zh-CN')
    expect(I18n.available_locales).to include(:'zh-CN', :en)
    expect(I18n.t('activerecord.attributes.pharma/pharmacy.name')).to eq('药店名称')
  end

  it 'provides Chinese labels for Spree Admin pages' do
    expect(Spree.t('admin.dashboard.hi')).to eq('你好')
    expect(Spree.t('admin.dashboard.top_products')).to eq('热销产品')
    expect(Spree.t('admin.tables.filters')).to eq('筛选')
    expect(Spree.t(:integrations)).to eq('集成')
    expect(Spree.t(:store_details)).to eq('店铺详情')
    expect(Spree.t(:completed_at)).to eq('完成时间')
    expect(Spree.t(:breadcrumb)).to eq('面包屑导航')
    expect(Spree.t(:api_keys)).to eq('API 密钥')
    expect(Spree.t(:new_store_credit_category)).to eq('新建储值金类型')
    expect(Spree.t(:payment_provider_settings)).to eq('支付服务商设置')
    expect(Spree.t(:product_translations)).to eq('产品翻译')
    expect(Spree.t(:no_report_data)).to eq('暂无报表数据')
    expect(Spree.t(:admin_locale_help)).to eq('后台管理界面使用的语言。未设置时会使用应用默认语言。')
    expect(Spree.t('admin.api_keys.name_placeholder')).to eq('例如：移动端生产环境')
    expect(Spree.t('admin.markets.list')).to eq('市场列表')
    expect(Spree.t('admin.webhook_endpoints.endpoint_settings')).to eq('端点设置')
    expect(I18n.t('activerecord.attributes.spree/store.contact_phone')).to eq('联系电话')
    expect(I18n.t('activerecord.attributes.spree/store.customer_support_email')).to eq('客服邮箱')
    expect(Spree::StoreCreditCategory.model_name.human).to eq('储值金类型')
    expect(Spree::ReturnAuthorizationReason.model_name.human).to eq('退货审批原因')
    expect(I18n.t('activerecord.attributes.spree/store.preferred_digital_asset_authorized_days')).to eq('数字资产可下载天数')
    expect(Spree.admin.tables.get(:price_lists).search_placeholder).to eq('搜索价格表')
    expect(Spree.admin.tables.get(:orders).search_placeholder).to eq('搜索订单')
  end
end
