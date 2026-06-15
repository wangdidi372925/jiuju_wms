# frozen_string_literal: true

class CreatePharmaInventoryImports < ActiveRecord::Migration[8.1]
  def change
    create_table :pharma_inventory_imports do |t|
      t.string :original_filename, null: false
      t.string :status, null: false, default: 'pending'
      t.integer :total_rows, null: false, default: 0
      t.integer :success_rows, null: false, default: 0
      t.integer :failed_rows, null: false, default: 0
      t.jsonb :error_details, null: false, default: []
      t.timestamps
    end

    add_index :pharma_inventory_imports, :status
    add_index :pharma_inventory_imports, :created_at
  end
end
