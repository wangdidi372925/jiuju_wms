# frozen_string_literal: true

class CreatePharmaPartyTables < ActiveRecord::Migration[8.1]
  def change
    create_table :pharma_pharmacies do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :contact_name, null: false
      t.string :contact_phone, null: false
      t.string :province, null: false
      t.string :city, null: false
      t.string :district
      t.string :address, null: false
      t.string :status, null: false, default: 'pending'
      t.timestamps
    end

    add_index :pharma_pharmacies, :code, unique: true
    add_index :pharma_pharmacies, :status

    create_table :pharma_pharmacy_licenses do |t|
      t.references :pharmacy, null: false, foreign_key: { to_table: :pharma_pharmacies }
      t.string :license_type, null: false
      t.string :license_no, null: false
      t.string :status, null: false, default: 'pending'
      t.date :starts_on, null: false
      t.date :expires_on, null: false
      t.timestamps
    end

    add_index :pharma_pharmacy_licenses,
              %i[pharmacy_id license_type license_no],
              unique: true,
              name: 'idx_pharma_pharmacy_licenses_unique_license'
    add_index :pharma_pharmacy_licenses, :status
    add_index :pharma_pharmacy_licenses, :expires_on

    create_table :pharma_suppliers do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :contact_name, null: false
      t.string :contact_phone, null: false
      t.string :province, null: false
      t.string :city, null: false
      t.string :status, null: false, default: 'pending'
      t.integer :priority, null: false, default: 0
      t.timestamps
    end

    add_index :pharma_suppliers, :code, unique: true
    add_index :pharma_suppliers, :status
    add_index :pharma_suppliers, :priority

    create_table :pharma_supplier_licenses do |t|
      t.references :supplier, null: false, foreign_key: { to_table: :pharma_suppliers }
      t.string :license_type, null: false
      t.string :license_no, null: false
      t.string :status, null: false, default: 'pending'
      t.date :starts_on, null: false
      t.date :expires_on, null: false
      t.timestamps
    end

    add_index :pharma_supplier_licenses,
              %i[supplier_id license_type license_no],
              unique: true,
              name: 'idx_pharma_supplier_licenses_unique_license'
    add_index :pharma_supplier_licenses, :status
    add_index :pharma_supplier_licenses, :expires_on

    create_table :pharma_supplier_warehouses do |t|
      t.references :supplier, null: false, foreign_key: { to_table: :pharma_suppliers }
      t.string :name, null: false
      t.string :code, null: false
      t.string :province, null: false
      t.string :city, null: false
      t.string :district
      t.string :address, null: false
      t.boolean :cold_chain_enabled, null: false, default: false
      t.string :status, null: false, default: 'active'
      t.timestamps
    end

    add_index :pharma_supplier_warehouses, :code, unique: true
    add_index :pharma_supplier_warehouses, :status

    create_table :pharma_supplier_visibility_configs do |t|
      t.string :mode, null: false, default: 'hidden'
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :pharma_supplier_visibility_configs,
              :active,
              unique: true,
              where: 'active = true',
              name: 'idx_one_active_supplier_visibility_config'
  end
end
