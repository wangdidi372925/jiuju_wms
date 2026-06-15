# frozen_string_literal: true

class LocalizeDefaultAdminUserName < ActiveRecord::Migration[8.1]
  class AdminUser < ActiveRecord::Base
    self.table_name = 'spree_admin_users'
  end

  def up
    return unless table_exists?(:spree_admin_users)

    AdminUser.where(first_name: 'Spree', last_name: 'Admin').update_all(
      first_name: '管理员',
      last_name: nil,
      updated_at: Time.current
    )
  end

  def down
    return unless table_exists?(:spree_admin_users)

    AdminUser.where(first_name: '管理员', last_name: nil).update_all(
      first_name: 'Spree',
      last_name: 'Admin',
      updated_at: Time.current
    )
  end
end
