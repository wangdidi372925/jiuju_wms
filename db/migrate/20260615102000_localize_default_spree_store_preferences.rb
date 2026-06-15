# frozen_string_literal: true

class LocalizeDefaultSpreeStorePreferences < ActiveRecord::Migration[8.1]
  def up
    each_store do |store|
      store.preferred_admin_locale = 'zh-CN' if store.preferred_admin_locale.blank? || store.preferred_admin_locale == 'en'
      store.preferred_timezone = 'Beijing' if store.preferred_timezone.blank? || store.preferred_timezone == 'UTC'
      store.save!(validate: false) if store.changed?
    end
  end

  def down
    each_store do |store|
      store.preferred_admin_locale = nil if store.preferred_admin_locale == 'zh-CN'
      store.preferred_timezone = 'UTC' if store.preferred_timezone == 'Beijing'
      store.save!(validate: false) if store.changed?
    end
  end

  private

  def each_store(&)
    return unless table_exists?(:spree_stores) && defined?(Spree::Store)

    Spree::Store.reset_column_information
    Spree::Store.unscoped.find_each(&)
  end
end
