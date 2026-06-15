# frozen_string_literal: true

class CreatePharmaFulfillmentTables < ActiveRecord::Migration[8.1]
  def change
    create_table :pharma_order_allocations do |t|
      t.bigint :spree_order_id, null: false
      t.bigint :spree_line_item_id, null: false
      t.references :supplier, null: false, foreign_key: { to_table: :pharma_suppliers }
      t.references :supplier_warehouse, null: false, foreign_key: { to_table: :pharma_supplier_warehouses }
      t.references :supplier_offer, null: false, foreign_key: { to_table: :pharma_supplier_offers }
      t.references :drug_batch_stock, null: false, foreign_key: { to_table: :pharma_drug_batch_stocks }
      t.string :supplier_name_snapshot, null: false
      t.string :batch_no_snapshot, null: false
      t.date :expiry_date_snapshot, null: false
      t.decimal :allocated_unit_price, precision: 12, scale: 2, null: false
      t.integer :allocated_quantity, null: false
      t.string :status, null: false, default: 'allocated'
      t.timestamps
    end
    add_index :pharma_order_allocations, :spree_order_id
    add_index :pharma_order_allocations, :spree_line_item_id
    add_index :pharma_order_allocations, :status

    create_table :pharma_supplier_fulfillments do |t|
      t.bigint :spree_order_id, null: false
      t.references :supplier, null: false, foreign_key: { to_table: :pharma_suppliers }
      t.references :supplier_warehouse, null: false, foreign_key: { to_table: :pharma_supplier_warehouses }
      t.string :fulfillment_no, null: false
      t.string :status, null: false, default: 'pending'
      t.string :delivery_company
      t.string :delivery_tracking_no
      t.datetime :shipped_at
      t.datetime :received_at
      t.timestamps
    end
    add_index :pharma_supplier_fulfillments, :spree_order_id
    add_index :pharma_supplier_fulfillments, :fulfillment_no, unique: true
    add_index :pharma_supplier_fulfillments, :status
  end
end
