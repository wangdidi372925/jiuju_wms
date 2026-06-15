# frozen_string_literal: true

class SetSpreeStoreLocaleToZhCn < ActiveRecord::Migration[8.1]
  class Store < ActiveRecord::Base
    self.table_name = 'spree_stores'
  end

  def up
    return unless table_exists?(:spree_stores)

    Store.update_all(
      default_locale: 'zh-CN',
      supported_locales: 'zh-CN,en',
      updated_at: Time.current
    )
  end

  def down
    return unless table_exists?(:spree_stores)

    Store.update_all(
      default_locale: 'en',
      supported_locales: nil,
      updated_at: Time.current
    )
  end
end
