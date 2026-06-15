# frozen_string_literal: true

class LocalizeDefaultSpreeStoreName < ActiveRecord::Migration[8.1]
  class Store < ActiveRecord::Base
    self.table_name = 'spree_stores'
  end

  SAMPLE_STORE_NAMES = ['Spree Test Store', 'Spree Demo Site', 'Spree Store'].freeze
  LOCALIZED_STORE_NAME = '九州药品采购平台'

  def up
    return unless table_exists?(:spree_stores)

    Store.where(name: SAMPLE_STORE_NAMES).update_all(
      name: LOCALIZED_STORE_NAME,
      updated_at: Time.current
    )
  end

  def down
    return unless table_exists?(:spree_stores)

    Store.where(name: LOCALIZED_STORE_NAME).update_all(
      name: 'Spree Test Store',
      updated_at: Time.current
    )
  end
end
