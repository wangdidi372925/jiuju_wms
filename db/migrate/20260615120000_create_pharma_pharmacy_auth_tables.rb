# frozen_string_literal: true

class CreatePharmaPharmacyAuthTables < ActiveRecord::Migration[8.1]
  def change
    create_table :pharma_pharmacy_users do |t|
      t.references :pharmacy, null: false, foreign_key: { to_table: :pharma_pharmacies }
      t.bigint :spree_user_id, null: false
      t.string :role, null: false, default: 'buyer'
      t.string :status, null: false, default: 'active'
      t.timestamps
    end

    add_foreign_key :pharma_pharmacy_users, :spree_users, column: :spree_user_id
    add_index :pharma_pharmacy_users, :spree_user_id
    add_index :pharma_pharmacy_users, %i[pharmacy_id spree_user_id], unique: true, name: 'idx_pharma_pharmacy_users_unique_user'
    add_index :pharma_pharmacy_users, :status

    create_table :pharma_pharmacy_api_tokens do |t|
      t.references :pharmacy_user, null: false, foreign_key: { to_table: :pharma_pharmacy_users }
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.datetime :expires_at
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :pharma_pharmacy_api_tokens, :token_digest, unique: true
    add_index :pharma_pharmacy_api_tokens, :token_prefix
    add_index :pharma_pharmacy_api_tokens, :expires_at
    add_index :pharma_pharmacy_api_tokens, :revoked_at
  end
end
