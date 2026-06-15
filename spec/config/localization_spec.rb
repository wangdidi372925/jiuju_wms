# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Localization' do
  it 'uses Simplified Chinese as the default application locale' do
    expect(I18n.default_locale).to eq(:'zh-CN')
    expect(I18n.available_locales).to include(:'zh-CN', :en)
    expect(I18n.t('activerecord.attributes.pharma/pharmacy.name')).to eq('药店名称')
  end
end
