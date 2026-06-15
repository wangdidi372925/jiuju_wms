# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

Spree::Core::Engine.load_seed if defined?(Spree::Core)

if defined?(Spree::Store)
  Spree::Store.find_each do |store|
    store.update!(
      default_locale: 'zh-CN',
      supported_locales: 'zh-CN,en'
    )
  end
end

if defined?(Spree::AdminUser) && !Rails.env.production?
  admin_email = ENV.fetch('SPREE_ADMIN_EMAIL', 'spree@example.com')
  admin_password = ENV.fetch('SPREE_ADMIN_PASSWORD', 'spree123')
  admin_user = Spree.admin_user_class.find_or_initialize_by(email: admin_email)

  unless admin_user.persisted? && admin_user.valid_password?(admin_password)
    admin_user.password = admin_password
    admin_user.password_confirmation = admin_password
    admin_user.save!
  end

  admin_role = Spree::Role.find_or_create_by!(name: 'admin')
  admin_user.spree_roles << admin_role unless admin_user.spree_roles.exists?(admin_role.id)

  puts "Spree 管理员账号：#{admin_email} / #{admin_password}"
end

load Rails.root.join('db/seeds/pharma_demo.rb')
