# frozen_string_literal: true

class CreatePharmaCatalogTables < ActiveRecord::Migration[8.1]
  def change
    create_table :pharma_drug_masters do |t|
      t.string :common_name, null: false
      t.string :trade_name
      t.string :specification, null: false
      t.string :dosage_form, null: false
      t.string :manufacturer, null: false
      t.string :approval_number, null: false
      t.string :package_unit, null: false
      t.boolean :prescription_required, null: false, default: false
      t.string :storage_condition, null: false
      t.string :temperature_control, null: false, default: 'normal'
      t.string :status, null: false, default: 'active'
      t.timestamps
    end
    add_index :pharma_drug_masters, :approval_number
    add_index :pharma_drug_masters,
              %i[common_name specification manufacturer],
              name: 'idx_pharma_drug_master_identity'
    add_index :pharma_drug_masters, :status

    create_table :pharma_drug_variant_links do |t|
      t.references :drug_master, null: false, foreign_key: { to_table: :pharma_drug_masters }
      t.bigint :spree_variant_id, null: false
      t.timestamps
    end
    add_index :pharma_drug_variant_links, :spree_variant_id, unique: true

    create_table :pharma_supplier_offers do |t|
      t.references :supplier, null: false, foreign_key: { to_table: :pharma_suppliers }
      t.references :drug_master, null: false, foreign_key: { to_table: :pharma_drug_masters }
      t.references :supplier_warehouse, null: false, foreign_key: { to_table: :pharma_supplier_warehouses }
      t.decimal :unit_price, precision: 12, scale: 2, null: false
      t.integer :min_order_quantity, null: false, default: 1
      t.integer :max_order_quantity
      t.string :status, null: false, default: 'draft'
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.timestamps
    end
    add_index :pharma_supplier_offers,
              %i[supplier_id drug_master_id supplier_warehouse_id],
              name: 'idx_pharma_supplier_offers_source'
    add_index :pharma_supplier_offers, :status
    add_index :pharma_supplier_offers, :unit_price

    create_table :pharma_supplier_offer_regions do |t|
      t.references :supplier_offer, null: false, foreign_key: { to_table: :pharma_supplier_offers }
      t.string :province, null: false
      t.string :city
      t.string :district
      t.integer :delivery_days, null: false, default: 3
      t.string :status, null: false, default: 'active'
      t.timestamps
    end
    add_index :pharma_supplier_offer_regions,
              %i[supplier_offer_id province city district],
              name: 'idx_pharma_offer_regions_lookup'
    add_index :pharma_supplier_offer_regions, :status

    create_table :pharma_drug_batch_stocks do |t|
      t.references :supplier, null: false, foreign_key: { to_table: :pharma_suppliers }
      t.references :supplier_warehouse, null: false, foreign_key: { to_table: :pharma_supplier_warehouses }
      t.references :drug_master, null: false, foreign_key: { to_table: :pharma_drug_masters }
      t.references :supplier_offer, null: false, foreign_key: { to_table: :pharma_supplier_offers }
      t.string :batch_no, null: false
      t.date :expiry_date, null: false
      t.integer :quantity_on_hand, null: false, default: 0
      t.integer :quantity_locked, null: false, default: 0
      t.string :status, null: false, default: 'active'
      t.timestamps
    end
    add_index :pharma_drug_batch_stocks,
              %i[supplier_id supplier_warehouse_id drug_master_id batch_no],
              unique: true,
              name: 'idx_pharma_batch_stock_unique_batch'
    add_index :pharma_drug_batch_stocks, :expiry_date
    add_index :pharma_drug_batch_stocks, :status
  end
end
