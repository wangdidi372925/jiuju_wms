# frozen_string_literal: true

class CreatePharmaAdminSecurityTables < ActiveRecord::Migration[8.1]
  def change
    create_table :pharma_admin_api_clients do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :token_prefix, null: false
      t.string :role, null: false, default: 'viewer'
      t.string :status, null: false, default: 'active'
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :pharma_admin_api_clients, :token_digest, unique: true
    add_index :pharma_admin_api_clients, :token_prefix
    add_index :pharma_admin_api_clients, :role
    add_index :pharma_admin_api_clients, :status

    create_table :pharma_admin_audit_logs do |t|
      t.references :admin_api_client, foreign_key: { to_table: :pharma_admin_api_clients }
      t.string :actor_name
      t.string :actor_role
      t.string :request_method, null: false
      t.string :path, null: false
      t.string :controller_path, null: false
      t.string :action_name, null: false
      t.integer :status, null: false
      t.string :error_code
      t.jsonb :request_params, null: false, default: {}
      t.string :ip_address
      t.string :user_agent
      t.datetime :occurred_at, null: false
      t.timestamps
    end

    add_index :pharma_admin_audit_logs, :actor_role
    add_index :pharma_admin_audit_logs, :request_method
    add_index :pharma_admin_audit_logs, :status
    add_index :pharma_admin_audit_logs, :error_code
    add_index :pharma_admin_audit_logs, :occurred_at
    add_index :pharma_admin_audit_logs, %i[controller_path action_name]
  end
end
