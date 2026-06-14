# Spree Pharma Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first working backend foundation for the Spree-based pharmacy B2B ordering system: a Dockerized Spree app plus tested pharma-domain models for pharmacies, suppliers, drug master data, offers, batch stock, visibility policy, and allocation records.

**Architecture:** Use `spree-starter` as the Rails/Spree backend application and keep custom pharmacy B2B logic in a separate `Pharma` namespace. Spree remains responsible for commerce primitives; `Pharma::*` models and services hold regulated drug, supplier, quote, stock, and fulfillment concepts.

**Tech Stack:** Ruby 4.0.1 in Docker, Rails 8.1, Spree 5.5 starter, PostgreSQL, Redis, Meilisearch, RSpec.

---

## Scope Check

The full design spec includes storefront UX, supplier operations, allocation automation, invoices, settlements, traceability, and later supplier self-service. This implementation plan intentionally covers only the first independently testable subsystem: backend foundation and pharma-domain core. Storefront pages, admin screens, supplier login, payments, and external integrations belong in later plans after this foundation is running.

## File Structure

- `Gemfile`, `Dockerfile`, `docker-compose.dev.yml`, `config/*`, `app/*`, `spec/*`: created by upstream `spree-starter`.
- `app/models/pharma.rb`: namespace table prefix for all custom pharma tables.
- `app/models/pharma/pharmacy.rb`: pharmacy buyer entity and purchase eligibility.
- `app/models/pharma/pharmacy_license.rb`: pharmacy license validity.
- `app/models/pharma/supplier.rb`: supply-side entity and offer eligibility.
- `app/models/pharma/supplier_license.rb`: supplier license validity.
- `app/models/pharma/supplier_warehouse.rb`: supplier warehouse and delivery metadata.
- `app/models/pharma/drug_master.rb`: regulated drug master data.
- `app/models/pharma/drug_variant_link.rb`: bridge between drug master data and Spree variants.
- `app/models/pharma/supplier_offer.rb`: supplier quote for a drug.
- `app/models/pharma/supplier_offer_region.rb`: regional sale/delivery rule for an offer.
- `app/models/pharma/drug_batch_stock.rb`: batch, expiry, and stock quantity.
- `app/models/pharma/order_allocation.rb`: order-line allocation to supplier, warehouse, offer, and batch.
- `app/models/pharma/supplier_fulfillment.rb`: supplier/warehouse fulfillment record.
- `app/models/pharma/supplier_visibility_config.rb`: singleton-ish display mode setting.
- `app/services/pharma/supplier_visibility_policy.rb`: maps supplier data to hidden, partial, or visible front-end output.
- `app/services/pharma/offer_matcher.rb`: filters and ranks available offers for a pharmacy and region.
- `db/migrate/20260614001000_create_pharma_party_tables.rb`: pharmacies, licenses, suppliers, warehouses, visibility config.
- `db/migrate/20260614002000_create_pharma_catalog_tables.rb`: drug master, variant links, offers, offer regions, batch stock.
- `db/migrate/20260614003000_create_pharma_fulfillment_tables.rb`: allocations and supplier fulfillments.
- `db/seeds/pharma_demo.rb`: small demo data set for local development.
- `spec/models/pharma/*_spec.rb`: model behavior tests.
- `spec/services/pharma/*_spec.rb`: service behavior tests.

### Task 1: Scaffold Spree Backend

**Files:**
- Create from upstream: `Gemfile`, `Gemfile.lock`, `.ruby-version`, `.env.example`, `Dockerfile`, `docker-compose.dev.yml`, `app/`, `bin/`, `config/`, `db/`, `spec/`
- Preserve existing: `docs/superpowers/specs/2026-06-14-spree-pharma-b2b-design.md`
- Preserve existing: `docs/superpowers/plans/2026-06-14-spree-pharma-foundation.md`

- [ ] **Step 1: Verify the workspace starts clean**

Run:

```bash
git status --short
```

Expected: either no output, or only this plan file if it has not been committed yet.

- [ ] **Step 2: Import the official Spree backend starter**

Run:

```bash
tmp_dir="$(mktemp -d)"
git clone --depth 1 https://github.com/spree/spree-starter.git "$tmp_dir/spree-starter"
rsync -a --exclude '.git' "$tmp_dir/spree-starter/" ./
rm -rf "$tmp_dir"
```

Expected: the repository now contains Rails/Spree files such as `Gemfile`, `Dockerfile`, `docker-compose.dev.yml`, `app/`, `config/`, `db/`, and `spec/`. Existing `docs/superpowers/*` files remain present.

- [ ] **Step 3: Create local environment file**

Run:

```bash
secret="$(docker run --rm ruby:slim ruby -e 'require "securerandom"; print SecureRandom.hex(64)')"
grep -v '^SECRET_KEY_BASE=' .env.example > .env
printf 'SECRET_KEY_BASE=%s\nSPREE_PORT=3000\nSPREE_DB_PORT=5433\n' "$secret" >> .env
```

Expected: `.env` exists locally and is ignored by Git.

- [ ] **Step 4: Build and start the development stack**

Run:

```bash
docker compose -f docker-compose.dev.yml up -d --build
```

Expected: `postgres`, `redis`, `meilisearch`, `web`, and `worker` containers start successfully.

- [ ] **Step 5: Prepare and seed the Spree database**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails db:prepare db:seed
```

Expected: database preparation succeeds and seed output prints admin credentials.

- [ ] **Step 6: Verify the Spree backend boots**

Run:

```bash
curl -fsS http://localhost:3000/up
```

Expected: command exits with status `0`.

- [ ] **Step 7: Run the starter test suite**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec
```

Expected: existing starter specs pass.

- [ ] **Step 8: Commit the scaffold**

Run:

```bash
git add .
git commit -m "chore: scaffold Spree backend"
```

Expected: a commit is created containing the Spree starter files and the existing docs.

### Task 2: Add Pharmacy, Supplier, License, Warehouse, and Visibility Config Models

**Files:**
- Create: `db/migrate/20260614001000_create_pharma_party_tables.rb`
- Create: `app/models/pharma.rb`
- Create: `app/models/pharma/pharmacy.rb`
- Create: `app/models/pharma/pharmacy_license.rb`
- Create: `app/models/pharma/supplier.rb`
- Create: `app/models/pharma/supplier_license.rb`
- Create: `app/models/pharma/supplier_warehouse.rb`
- Create: `app/models/pharma/supplier_visibility_config.rb`
- Test: `spec/models/pharma/party_spec.rb`

- [ ] **Step 1: Write failing model specs**

Create `spec/models/pharma/party_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma party models', type: :model do
  describe Pharma::Pharmacy do
    it 'is purchasing enabled only when approved and holding an effective approved license' do
      pharmacy = Pharma::Pharmacy.create!(
        name: '九州一号药店',
        code: 'PH-001',
        contact_name: '王店长',
        contact_phone: '13800000001',
        province: '上海市',
        city: '上海市',
        district: '浦东新区',
        address: '张江路 1 号',
        status: 'approved'
      )

      Pharma::PharmacyLicense.create!(
        pharmacy: pharmacy,
        license_type: 'drug_business_license',
        license_no: '沪药营-001',
        status: 'approved',
        starts_on: Date.current - 30.days,
        expires_on: Date.current + 1.year
      )

      expect(pharmacy.reload.purchasing_enabled?).to be(true)
    end
  end

  describe Pharma::Supplier do
    it 'is active for offers only when approved and holding an effective approved license' do
      supplier = Pharma::Supplier.create!(
        name: '华东医药供货有限公司',
        code: 'SUP-001',
        contact_name: '李经理',
        contact_phone: '13900000001',
        province: '上海市',
        city: '上海市',
        status: 'approved',
        priority: 10
      )

      Pharma::SupplierLicense.create!(
        supplier: supplier,
        license_type: 'drug_wholesale_license',
        license_no: '沪批发-001',
        status: 'approved',
        starts_on: Date.current - 30.days,
        expires_on: Date.current + 1.year
      )

      expect(supplier.reload.active_for_offers?).to be(true)
    end
  end

  describe Pharma::SupplierVisibilityConfig do
    it 'defaults to hidden supplier visibility' do
      expect(described_class.current.mode).to eq('hidden')
    end
  end
end
```

- [ ] **Step 2: Run specs and confirm they fail because models do not exist**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/models/pharma/party_spec.rb
```

Expected: FAIL with an uninitialized constant such as `Pharma`.

- [ ] **Step 3: Add the party schema migration**

Create `db/migrate/20260614001000_create_pharma_party_tables.rb`:

```ruby
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
    add_index :pharma_pharmacy_licenses, %i[pharmacy_id license_type license_no], unique: true, name: 'idx_pharma_pharmacy_licenses_unique_license'
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
    add_index :pharma_supplier_licenses, %i[supplier_id license_type license_no], unique: true, name: 'idx_pharma_supplier_licenses_unique_license'
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
    add_index :pharma_supplier_visibility_configs, :active, unique: true, where: 'active = true', name: 'idx_one_active_supplier_visibility_config'
  end
end
```

- [ ] **Step 4: Add party models**

Create `app/models/pharma.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  def self.table_name_prefix
    'pharma_'
  end
end
```

Create `app/models/pharma/pharmacy.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class Pharmacy < ApplicationRecord
    STATUSES = %w[pending approved suspended rejected].freeze

    has_many :pharmacy_licenses, dependent: :destroy

    validates :name, :code, :contact_name, :contact_phone, :province, :city, :address, :status, presence: true
    validates :code, uniqueness: true
    validates :status, inclusion: { in: STATUSES }

    def purchasing_enabled?
      status == 'approved' && pharmacy_licenses.any?(&:effective?)
    end
  end
end
```

Create `app/models/pharma/pharmacy_license.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class PharmacyLicense < ApplicationRecord
    STATUSES = %w[pending approved rejected expired].freeze

    belongs_to :pharmacy

    validates :license_type, :license_no, :status, :starts_on, :expires_on, presence: true
    validates :license_no, uniqueness: { scope: %i[pharmacy_id license_type] }
    validates :status, inclusion: { in: STATUSES }
    validate :expires_after_start

    def effective?(on: Date.current)
      status == 'approved' && starts_on <= on && expires_on >= on
    end

    private

    def expires_after_start
      return if starts_on.blank? || expires_on.blank?

      errors.add(:expires_on, 'must be on or after starts_on') if expires_on < starts_on
    end
  end
end
```

Create `app/models/pharma/supplier.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class Supplier < ApplicationRecord
    STATUSES = %w[pending approved suspended rejected].freeze

    has_many :supplier_licenses, dependent: :destroy
    has_many :supplier_warehouses, dependent: :destroy

    validates :name, :code, :contact_name, :contact_phone, :province, :city, :status, presence: true
    validates :code, uniqueness: true
    validates :status, inclusion: { in: STATUSES }
    validates :priority, numericality: { only_integer: true }

    def active_for_offers?
      status == 'approved' && supplier_licenses.any?(&:effective?)
    end
  end
end
```

Create `app/models/pharma/supplier_license.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class SupplierLicense < ApplicationRecord
    STATUSES = %w[pending approved rejected expired].freeze

    belongs_to :supplier

    validates :license_type, :license_no, :status, :starts_on, :expires_on, presence: true
    validates :license_no, uniqueness: { scope: %i[supplier_id license_type] }
    validates :status, inclusion: { in: STATUSES }
    validate :expires_after_start

    def effective?(on: Date.current)
      status == 'approved' && starts_on <= on && expires_on >= on
    end

    private

    def expires_after_start
      return if starts_on.blank? || expires_on.blank?

      errors.add(:expires_on, 'must be on or after starts_on') if expires_on < starts_on
    end
  end
end
```

Create `app/models/pharma/supplier_warehouse.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class SupplierWarehouse < ApplicationRecord
    STATUSES = %w[active suspended closed].freeze

    belongs_to :supplier

    validates :name, :code, :province, :city, :address, :status, presence: true
    validates :code, uniqueness: true
    validates :status, inclusion: { in: STATUSES }

    def active?
      status == 'active'
    end

    def region_label
      [province, city, district].compact_blank.join(' / ')
    end
  end
end
```

Create `app/models/pharma/supplier_visibility_config.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class SupplierVisibilityConfig < ApplicationRecord
    MODES = %w[hidden partial visible].freeze

    validates :mode, presence: true, inclusion: { in: MODES }
    validates :active, uniqueness: true, if: :active?

    def self.current
      where(active: true).first_or_create!(mode: 'hidden')
    end
  end
end
```

- [ ] **Step 5: Migrate and run party specs**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails db:migrate
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/models/pharma/party_spec.rb
```

Expected: specs pass.

- [ ] **Step 6: Commit party models**

Run:

```bash
git add db/migrate/20260614001000_create_pharma_party_tables.rb app/models/pharma.rb app/models/pharma spec/models/pharma/party_spec.rb db/schema.rb
git commit -m "feat: add pharma party models"
```

Expected: a commit is created for pharmacy, supplier, license, warehouse, and visibility config models.

### Task 3: Add Drug Master, Supplier Offer, Region, and Batch Stock Models

**Files:**
- Create: `db/migrate/20260614002000_create_pharma_catalog_tables.rb`
- Create: `app/models/pharma/drug_master.rb`
- Create: `app/models/pharma/drug_variant_link.rb`
- Create: `app/models/pharma/supplier_offer.rb`
- Create: `app/models/pharma/supplier_offer_region.rb`
- Create: `app/models/pharma/drug_batch_stock.rb`
- Test: `spec/models/pharma/catalog_spec.rb`

- [ ] **Step 1: Write failing catalog specs**

Create `spec/models/pharma/catalog_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma catalog models', type: :model do
  let(:supplier) do
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-CAT-001',
      contact_name: '李经理',
      contact_phone: '13900000002',
      province: '上海市',
      city: '上海市',
      status: 'approved',
      priority: 20
    ).tap do |record|
      Pharma::SupplierLicense.create!(
        supplier: record,
        license_type: 'drug_wholesale_license',
        license_no: '沪批发-CAT-001',
        status: 'approved',
        starts_on: Date.current - 30.days,
        expires_on: Date.current + 1.year
      )
    end
  end

  let(:warehouse) do
    Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: '上海中心仓',
      code: 'WH-CAT-001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '仓库路 1 号',
      cold_chain_enabled: false,
      status: 'active'
    )
  end

  let(:drug) do
    Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      trade_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字H00000001',
      package_unit: '盒',
      prescription_required: true,
      storage_condition: '常温',
      temperature_control: 'normal'
    )
  end

  it 'builds a readable drug display name' do
    expect(drug.display_name).to eq('阿莫西林胶囊 0.25g*24粒 示例制药有限公司')
  end

  it 'marks an offer available when supplier, region, warehouse, stock, and expiry all qualify' do
    offer = Pharma::SupplierOffer.create!(
      supplier: supplier,
      drug_master: drug,
      supplier_warehouse: warehouse,
      unit_price: 8.5,
      min_order_quantity: 10,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    )

    Pharma::SupplierOfferRegion.create!(
      supplier_offer: offer,
      province: '上海市',
      city: '上海市',
      delivery_days: 1,
      status: 'active'
    )

    Pharma::DrugBatchStock.create!(
      supplier: supplier,
      supplier_warehouse: warehouse,
      drug_master: drug,
      supplier_offer: offer,
      batch_no: 'BATCH-001',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: 100,
      quantity_locked: 20,
      status: 'active'
    )

    expect(offer.available_for?(province: '上海市', city: '上海市', quantity: 30)).to be(true)
    expect(offer.available_quantity).to eq(80)
  end
end
```

- [ ] **Step 2: Run catalog specs and confirm they fail because models do not exist**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/models/pharma/catalog_spec.rb
```

Expected: FAIL with an uninitialized constant such as `Pharma::DrugMaster`.

- [ ] **Step 3: Add catalog schema migration**

Create `db/migrate/20260614002000_create_pharma_catalog_tables.rb`:

```ruby
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
    add_index :pharma_drug_masters, %i[common_name specification manufacturer], name: 'idx_pharma_drug_master_identity'
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
    add_index :pharma_supplier_offers, %i[supplier_id drug_master_id supplier_warehouse_id], name: 'idx_pharma_supplier_offers_source'
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
    add_index :pharma_supplier_offer_regions, %i[supplier_offer_id province city district], name: 'idx_pharma_offer_regions_lookup'
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
    add_index :pharma_drug_batch_stocks, %i[supplier_id supplier_warehouse_id drug_master_id batch_no], unique: true, name: 'idx_pharma_batch_stock_unique_batch'
    add_index :pharma_drug_batch_stocks, :expiry_date
    add_index :pharma_drug_batch_stocks, :status
  end
end
```

- [ ] **Step 4: Add catalog models**

Create `app/models/pharma/drug_master.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class DrugMaster < ApplicationRecord
    TEMPERATURE_CONTROLS = %w[normal cool cold_chain].freeze
    STATUSES = %w[active inactive].freeze

    has_many :drug_variant_links, dependent: :destroy
    has_many :supplier_offers, dependent: :restrict_with_error
    has_many :drug_batch_stocks, dependent: :restrict_with_error

    validates :common_name, :specification, :dosage_form, :manufacturer, :approval_number,
              :package_unit, :storage_condition, :temperature_control, :status, presence: true
    validates :temperature_control, inclusion: { in: TEMPERATURE_CONTROLS }
    validates :status, inclusion: { in: STATUSES }

    def display_name
      [common_name, specification, manufacturer].join(' ')
    end
  end
end
```

Create `app/models/pharma/drug_variant_link.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class DrugVariantLink < ApplicationRecord
    belongs_to :drug_master
    belongs_to :variant, class_name: 'Spree::Variant', foreign_key: :spree_variant_id, inverse_of: false

    validates :spree_variant_id, uniqueness: true
  end
end
```

Create `app/models/pharma/supplier_offer.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class SupplierOffer < ApplicationRecord
    STATUSES = %w[draft approved suspended expired].freeze

    belongs_to :supplier
    belongs_to :drug_master
    belongs_to :supplier_warehouse
    has_many :supplier_offer_regions, dependent: :destroy
    has_many :drug_batch_stocks, dependent: :restrict_with_error

    validates :unit_price, numericality: { greater_than: 0 }
    validates :min_order_quantity, numericality: { only_integer: true, greater_than: 0 }
    validates :max_order_quantity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :status, :starts_at, :ends_at, presence: true
    validates :status, inclusion: { in: STATUSES }
    validate :ends_after_start

    def available_for?(province:, city:, quantity:, on: Time.current, min_expiry_date: 180.days.from_now.to_date)
      status == 'approved' &&
        starts_at <= on &&
        ends_at >= on &&
        supplier.active_for_offers? &&
        supplier_warehouse.active? &&
        quantity >= min_order_quantity &&
        within_max_order_quantity?(quantity) &&
        region_available?(province: province, city: city) &&
        available_stock(min_expiry_date: min_expiry_date).sum(&:available_quantity) >= quantity
    end

    def available_quantity(min_expiry_date: Date.current)
      available_stock(min_expiry_date: min_expiry_date).sum(&:available_quantity)
    end

    def best_available_stock(min_expiry_date: Date.current)
      available_stock(min_expiry_date: min_expiry_date).max_by(&:expiry_date)
    end

    private

    def available_stock(min_expiry_date:)
      drug_batch_stocks.select { |stock| stock.available?(min_expiry_date: min_expiry_date) }
    end

    def region_available?(province:, city:)
      supplier_offer_regions.any? { |region| region.available_for?(province: province, city: city) }
    end

    def within_max_order_quantity?(quantity)
      max_order_quantity.blank? || quantity <= max_order_quantity
    end

    def ends_after_start
      return if starts_at.blank? || ends_at.blank?

      errors.add(:ends_at, 'must be after starts_at') if ends_at <= starts_at
    end
  end
end
```

Create `app/models/pharma/supplier_offer_region.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class SupplierOfferRegion < ApplicationRecord
    STATUSES = %w[active suspended].freeze

    belongs_to :supplier_offer

    validates :province, :delivery_days, :status, presence: true
    validates :delivery_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :status, inclusion: { in: STATUSES }

    def available_for?(province:, city:)
      status == 'active' && self.province == province && (self.city.blank? || self.city == city)
    end
  end
end
```

Create `app/models/pharma/drug_batch_stock.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class DrugBatchStock < ApplicationRecord
    STATUSES = %w[active locked expired recalled].freeze

    belongs_to :supplier
    belongs_to :supplier_warehouse
    belongs_to :drug_master
    belongs_to :supplier_offer

    validates :batch_no, :expiry_date, :status, presence: true
    validates :quantity_on_hand, :quantity_locked, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :status, inclusion: { in: STATUSES }
    validate :locked_not_greater_than_on_hand

    def available_quantity
      quantity_on_hand - quantity_locked
    end

    def available?(min_expiry_date: Date.current)
      status == 'active' && expiry_date >= min_expiry_date && available_quantity.positive?
    end

    private

    def locked_not_greater_than_on_hand
      return if quantity_on_hand.blank? || quantity_locked.blank?

      errors.add(:quantity_locked, 'cannot exceed quantity_on_hand') if quantity_locked > quantity_on_hand
    end
  end
end
```

- [ ] **Step 5: Migrate and run catalog specs**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails db:migrate
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/models/pharma/catalog_spec.rb
```

Expected: specs pass.

- [ ] **Step 6: Commit catalog models**

Run:

```bash
git add db/migrate/20260614002000_create_pharma_catalog_tables.rb app/models/pharma spec/models/pharma/catalog_spec.rb db/schema.rb
git commit -m "feat: add pharma catalog and stock models"
```

Expected: a commit is created for drug master, offer, region, and batch stock models.

### Task 4: Add Order Allocation and Supplier Fulfillment Models

**Files:**
- Create: `db/migrate/20260614003000_create_pharma_fulfillment_tables.rb`
- Create: `app/models/pharma/order_allocation.rb`
- Create: `app/models/pharma/supplier_fulfillment.rb`
- Test: `spec/models/pharma/fulfillment_spec.rb`

- [ ] **Step 1: Write failing fulfillment specs**

Create `spec/models/pharma/fulfillment_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma fulfillment models', type: :model do
  it 'stores allocation snapshots needed for hidden supplier storefront mode' do
    supplier = Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-FUL-001',
      contact_name: '李经理',
      contact_phone: '13900000003',
      province: '上海市',
      city: '上海市',
      status: 'approved'
    )
    warehouse = Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: '上海中心仓',
      code: 'WH-FUL-001',
      province: '上海市',
      city: '上海市',
      address: '仓库路 2 号',
      status: 'active'
    )
    drug = Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字H00000002',
      package_unit: '盒',
      storage_condition: '常温',
      temperature_control: 'normal'
    )
    offer = Pharma::SupplierOffer.create!(
      supplier: supplier,
      drug_master: drug,
      supplier_warehouse: warehouse,
      unit_price: 8.5,
      min_order_quantity: 1,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    )
    stock = Pharma::DrugBatchStock.create!(
      supplier: supplier,
      supplier_warehouse: warehouse,
      drug_master: drug,
      supplier_offer: offer,
      batch_no: 'BATCH-FUL-001',
      expiry_date: Date.current + 2.years,
      quantity_on_hand: 100,
      quantity_locked: 0,
      status: 'active'
    )

    allocation = Pharma::OrderAllocation.create!(
      spree_order_id: 1001,
      spree_line_item_id: 2001,
      supplier: supplier,
      supplier_warehouse: warehouse,
      supplier_offer: offer,
      drug_batch_stock: stock,
      supplier_name_snapshot: supplier.name,
      batch_no_snapshot: stock.batch_no,
      expiry_date_snapshot: stock.expiry_date,
      allocated_unit_price: 8.5,
      allocated_quantity: 10,
      status: 'allocated'
    )

    expect(allocation.total_amount).to eq(BigDecimal('85.0'))
    expect(allocation.supplier_name_snapshot).to eq('华东医药供货有限公司')
  end
end
```

- [ ] **Step 2: Run fulfillment specs and confirm they fail because models do not exist**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/models/pharma/fulfillment_spec.rb
```

Expected: FAIL with an uninitialized constant such as `Pharma::OrderAllocation`.

- [ ] **Step 3: Add fulfillment schema migration**

Create `db/migrate/20260614003000_create_pharma_fulfillment_tables.rb`:

```ruby
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
```

- [ ] **Step 4: Add fulfillment models**

Create `app/models/pharma/order_allocation.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class OrderAllocation < ApplicationRecord
    STATUSES = %w[allocated confirmed canceled fulfilled].freeze

    belongs_to :supplier
    belongs_to :supplier_warehouse
    belongs_to :supplier_offer
    belongs_to :drug_batch_stock
    belongs_to :spree_order, class_name: 'Spree::Order', foreign_key: :spree_order_id, inverse_of: false, optional: true
    belongs_to :spree_line_item, class_name: 'Spree::LineItem', foreign_key: :spree_line_item_id, inverse_of: false, optional: true

    validates :spree_order_id, :spree_line_item_id, :supplier_name_snapshot, :batch_no_snapshot,
              :expiry_date_snapshot, :allocated_unit_price, :allocated_quantity, :status, presence: true
    validates :allocated_unit_price, numericality: { greater_than_or_equal_to: 0 }
    validates :allocated_quantity, numericality: { only_integer: true, greater_than: 0 }
    validates :status, inclusion: { in: STATUSES }

    def total_amount
      allocated_unit_price * allocated_quantity
    end
  end
end
```

Create `app/models/pharma/supplier_fulfillment.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class SupplierFulfillment < ApplicationRecord
    STATUSES = %w[pending picking shipped received canceled].freeze

    belongs_to :supplier
    belongs_to :supplier_warehouse
    belongs_to :spree_order, class_name: 'Spree::Order', foreign_key: :spree_order_id, inverse_of: false, optional: true

    validates :spree_order_id, :fulfillment_no, :status, presence: true
    validates :fulfillment_no, uniqueness: true
    validates :status, inclusion: { in: STATUSES }

    def shipped?
      shipped_at.present?
    end

    def received?
      received_at.present?
    end
  end
end
```

- [ ] **Step 5: Migrate and run fulfillment specs**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails db:migrate
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/models/pharma/fulfillment_spec.rb
```

Expected: specs pass.

- [ ] **Step 6: Commit fulfillment models**

Run:

```bash
git add db/migrate/20260614003000_create_pharma_fulfillment_tables.rb app/models/pharma/order_allocation.rb app/models/pharma/supplier_fulfillment.rb spec/models/pharma/fulfillment_spec.rb db/schema.rb
git commit -m "feat: add pharma allocation and fulfillment models"
```

Expected: a commit is created for allocation and fulfillment records.

### Task 5: Add Supplier Visibility and Offer Matching Services

**Files:**
- Create: `app/services/pharma/supplier_visibility_policy.rb`
- Create: `app/services/pharma/offer_matcher.rb`
- Test: `spec/services/pharma/supplier_visibility_policy_spec.rb`
- Test: `spec/services/pharma/offer_matcher_spec.rb`

- [ ] **Step 1: Write failing service specs**

Create `spec/services/pharma/supplier_visibility_policy_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharma::SupplierVisibilityPolicy do
  let(:supplier) do
    Pharma::Supplier.create!(
      name: '华东医药供货有限公司',
      code: 'SUP-VIS-001',
      contact_name: '李经理',
      contact_phone: '13900000004',
      province: '上海市',
      city: '上海市',
      status: 'approved'
    )
  end

  let(:warehouse) do
    Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: '上海中心仓',
      code: 'WH-VIS-001',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '仓库路 3 号',
      status: 'active'
    )
  end

  it 'hides supplier identity in hidden mode' do
    result = described_class.new(mode: 'hidden').present(supplier: supplier, warehouse: warehouse)

    expect(result).to eq(
      mode: 'hidden',
      supplier_visible: false,
      supplier_name: nil,
      label: '平台优选'
    )
  end

  it 'shows regional warehouse label in partial mode' do
    result = described_class.new(mode: 'partial').present(supplier: supplier, warehouse: warehouse)

    expect(result).to eq(
      mode: 'partial',
      supplier_visible: false,
      supplier_name: nil,
      label: '上海市 / 上海市 / 浦东新区'
    )
  end

  it 'shows supplier identity in visible mode' do
    result = described_class.new(mode: 'visible').present(supplier: supplier, warehouse: warehouse)

    expect(result).to eq(
      mode: 'visible',
      supplier_visible: true,
      supplier_name: '华东医药供货有限公司',
      label: '华东医药供货有限公司'
    )
  end
end
```

Create `spec/services/pharma/offer_matcher_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pharma::OfferMatcher do
  def approved_supplier(code:, priority:)
    Pharma::Supplier.create!(
      name: "供应商#{code}",
      code: code,
      contact_name: '李经理',
      contact_phone: "139#{priority.to_s.rjust(8, '0')}",
      province: '上海市',
      city: '上海市',
      status: 'approved',
      priority: priority
    ).tap do |supplier|
      Pharma::SupplierLicense.create!(
        supplier: supplier,
        license_type: 'drug_wholesale_license',
        license_no: "LICENSE-#{code}",
        status: 'approved',
        starts_on: Date.current - 1.day,
        expires_on: Date.current + 1.year
      )
    end
  end

  def warehouse_for(supplier, code)
    Pharma::SupplierWarehouse.create!(
      supplier: supplier,
      name: "仓库#{code}",
      code: code,
      province: '上海市',
      city: '上海市',
      address: "仓库#{code}地址",
      status: 'active'
    )
  end

  let(:pharmacy) do
    Pharma::Pharmacy.create!(
      name: '九州一号药店',
      code: 'PH-MATCH-001',
      contact_name: '王店长',
      contact_phone: '13800000005',
      province: '上海市',
      city: '上海市',
      district: '浦东新区',
      address: '张江路 5 号',
      status: 'approved'
    ).tap do |record|
      Pharma::PharmacyLicense.create!(
        pharmacy: record,
        license_type: 'drug_business_license',
        license_no: 'PH-MATCH-LICENSE-001',
        status: 'approved',
        starts_on: Date.current - 1.day,
        expires_on: Date.current + 1.year
      )
    end
  end

  let(:drug) do
    Pharma::DrugMaster.create!(
      common_name: '阿莫西林胶囊',
      specification: '0.25g*24粒',
      dosage_form: '胶囊剂',
      manufacturer: '示例制药有限公司',
      approval_number: '国药准字H00000003',
      package_unit: '盒',
      storage_condition: '常温',
      temperature_control: 'normal'
    )
  end

  it 'returns only available offers sorted by price, supplier priority, and delivery days' do
    expensive_supplier = approved_supplier(code: 'SUP-MATCH-001', priority: 1)
    cheap_supplier = approved_supplier(code: 'SUP-MATCH-002', priority: 10)

    expensive_warehouse = warehouse_for(expensive_supplier, 'WH-MATCH-001')
    cheap_warehouse = warehouse_for(cheap_supplier, 'WH-MATCH-002')

    expensive_offer = Pharma::SupplierOffer.create!(
      supplier: expensive_supplier,
      drug_master: drug,
      supplier_warehouse: expensive_warehouse,
      unit_price: 9.0,
      min_order_quantity: 1,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    )
    cheap_offer = Pharma::SupplierOffer.create!(
      supplier: cheap_supplier,
      drug_master: drug,
      supplier_warehouse: cheap_warehouse,
      unit_price: 8.5,
      min_order_quantity: 1,
      status: 'approved',
      starts_at: 1.day.ago,
      ends_at: 30.days.from_now
    )

    [expensive_offer, cheap_offer].each_with_index do |offer, index|
      Pharma::SupplierOfferRegion.create!(
        supplier_offer: offer,
        province: '上海市',
        city: '上海市',
        delivery_days: index + 1,
        status: 'active'
      )
      Pharma::DrugBatchStock.create!(
        supplier: offer.supplier,
        supplier_warehouse: offer.supplier_warehouse,
        drug_master: drug,
        supplier_offer: offer,
        batch_no: "BATCH-MATCH-#{index}",
        expiry_date: Date.current + 2.years,
        quantity_on_hand: 100,
        quantity_locked: 0,
        status: 'active'
      )
    end

    result = described_class.new.call(
      drug_master: drug,
      pharmacy: pharmacy,
      quantity: 10,
      province: '上海市',
      city: '上海市'
    )

    expect(result).to eq([cheap_offer, expensive_offer])
  end
end
```

- [ ] **Step 2: Run service specs and confirm they fail because services do not exist**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/services/pharma
```

Expected: FAIL with uninitialized constants for `Pharma::SupplierVisibilityPolicy` and `Pharma::OfferMatcher`.

- [ ] **Step 3: Add visibility policy service**

Create `app/services/pharma/supplier_visibility_policy.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class SupplierVisibilityPolicy
    VALID_MODES = %w[hidden partial visible].freeze

    def initialize(mode:)
      raise ArgumentError, "unknown supplier visibility mode: #{mode}" unless VALID_MODES.include?(mode)

      @mode = mode
    end

    def present(supplier:, warehouse:)
      case mode
      when 'hidden'
        hidden_payload
      when 'partial'
        partial_payload(warehouse)
      when 'visible'
        visible_payload(supplier)
      end
    end

    private

    attr_reader :mode

    def hidden_payload
      {
        mode: mode,
        supplier_visible: false,
        supplier_name: nil,
        label: '平台优选'
      }
    end

    def partial_payload(warehouse)
      {
        mode: mode,
        supplier_visible: false,
        supplier_name: nil,
        label: warehouse.region_label
      }
    end

    def visible_payload(supplier)
      {
        mode: mode,
        supplier_visible: true,
        supplier_name: supplier.name,
        label: supplier.name
      }
    end
  end
end
```

- [ ] **Step 4: Add offer matcher service**

Create `app/services/pharma/offer_matcher.rb`:

```ruby
# frozen_string_literal: true

module Pharma
  class OfferMatcher
    DEFAULT_MIN_EXPIRY_DAYS = 180

    def call(drug_master:, pharmacy:, quantity:, province:, city: nil, min_expiry_date: DEFAULT_MIN_EXPIRY_DAYS.days.from_now.to_date)
      return [] unless pharmacy.purchasing_enabled?

      SupplierOffer
        .includes(:supplier, :supplier_warehouse, :supplier_offer_regions, :drug_batch_stocks)
        .where(drug_master: drug_master, status: 'approved')
        .select do |offer|
          offer.available_for?(
            province: province,
            city: city,
            quantity: quantity,
            min_expiry_date: min_expiry_date
          )
        end
        .sort_by { |offer| ranking_key(offer, province: province, city: city, min_expiry_date: min_expiry_date) }
    end

    private

    def ranking_key(offer, province:, city:, min_expiry_date:)
      [
        offer.unit_price,
        -offer.supplier.priority,
        delivery_days_for(offer, province: province, city: city),
        -offer.best_available_stock(min_expiry_date: min_expiry_date).expiry_date.to_time.to_i
      ]
    end

    def delivery_days_for(offer, province:, city:)
      offer.supplier_offer_regions
           .select { |region| region.available_for?(province: province, city: city) }
           .map(&:delivery_days)
           .min || 99
    end
  end
end
```

- [ ] **Step 5: Run service specs**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/services/pharma
```

Expected: specs pass.

- [ ] **Step 6: Run all pharma specs**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/models/pharma spec/services/pharma
```

Expected: all pharma specs pass.

- [ ] **Step 7: Commit services**

Run:

```bash
git add app/services/pharma spec/services/pharma
git commit -m "feat: add pharma offer matching services"
```

Expected: a commit is created for supplier visibility and offer matching services.

### Task 6: Add Demo Seeds and Final Verification

**Files:**
- Create: `db/seeds/pharma_demo.rb`
- Modify: `db/seeds.rb`
- Modify: `README.md`

- [ ] **Step 1: Add pharma demo seed file**

Create `db/seeds/pharma_demo.rb`:

```ruby
# frozen_string_literal: true

supplier = Pharma::Supplier.find_or_create_by!(code: 'SUP-DEMO-001') do |record|
  record.name = '华东医药供货有限公司'
  record.contact_name = '李经理'
  record.contact_phone = '13900000999'
  record.province = '上海市'
  record.city = '上海市'
  record.status = 'approved'
  record.priority = 10
end

Pharma::SupplierLicense.find_or_create_by!(
  supplier: supplier,
  license_type: 'drug_wholesale_license',
  license_no: '沪批发-DEMO-001'
) do |record|
  record.status = 'approved'
  record.starts_on = Date.current - 30.days
  record.expires_on = Date.current + 1.year
end

warehouse = Pharma::SupplierWarehouse.find_or_create_by!(code: 'WH-DEMO-001') do |record|
  record.supplier = supplier
  record.name = '上海中心仓'
  record.province = '上海市'
  record.city = '上海市'
  record.district = '浦东新区'
  record.address = '仓库路 8 号'
  record.status = 'active'
end

drug = Pharma::DrugMaster.find_or_create_by!(approval_number: '国药准字H00000001') do |record|
  record.common_name = '阿莫西林胶囊'
  record.trade_name = '阿莫西林胶囊'
  record.specification = '0.25g*24粒'
  record.dosage_form = '胶囊剂'
  record.manufacturer = '示例制药有限公司'
  record.package_unit = '盒'
  record.prescription_required = true
  record.storage_condition = '常温'
  record.temperature_control = 'normal'
  record.status = 'active'
end

offer = Pharma::SupplierOffer.find_or_create_by!(
  supplier: supplier,
  drug_master: drug,
  supplier_warehouse: warehouse
) do |record|
  record.unit_price = 8.5
  record.min_order_quantity = 10
  record.status = 'approved'
  record.starts_at = 1.day.ago
  record.ends_at = 30.days.from_now
end

Pharma::SupplierOfferRegion.find_or_create_by!(
  supplier_offer: offer,
  province: '上海市',
  city: '上海市',
  district: nil
) do |record|
  record.delivery_days = 1
  record.status = 'active'
end

Pharma::DrugBatchStock.find_or_create_by!(
  supplier: supplier,
  supplier_warehouse: warehouse,
  drug_master: drug,
  supplier_offer: offer,
  batch_no: 'DEMO-BATCH-001'
) do |record|
  record.expiry_date = Date.current + 2.years
  record.quantity_on_hand = 300
  record.quantity_locked = 0
  record.status = 'active'
end

Pharma::SupplierVisibilityConfig.current
```

- [ ] **Step 2: Load pharma demo seeds from the main seed file**

Append this exact line to `db/seeds.rb` unless it already exists:

```ruby
load Rails.root.join('db/seeds/pharma_demo.rb')
```

- [ ] **Step 3: Add README development notes**

Append this section to `README.md`:

````markdown

## Jiuju WMS Pharma B2B Development

This project uses Spree as the commerce backend and keeps regulated pharmacy B2B logic under the `Pharma` namespace.

Common local commands:

```bash
docker compose -f docker-compose.dev.yml up -d
docker compose -f docker-compose.dev.yml exec web bin/rails db:prepare db:seed
docker compose -f docker-compose.dev.yml exec web bundle exec rspec spec/models/pharma spec/services/pharma
```

Supplier visibility modes are stored in `Pharma::SupplierVisibilityConfig`:

- `hidden`: pharmacy buyers see platform labels only.
- `partial`: pharmacy buyers see regional warehouse labels.
- `visible`: pharmacy buyers see the actual supplier name.
````

- [ ] **Step 4: Run seeds**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails db:seed
```

Expected: seed command succeeds and creates demo pharma records without duplicates.

- [ ] **Step 5: Verify demo data through Rails runner**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails runner "pharmacy = Pharma::Pharmacy.find_or_create_by!(code: 'PH-TMP-001') { |record| record.name = '临时药店'; record.contact_name = '测试'; record.contact_phone = '13811111111'; record.province = '上海市'; record.city = '上海市'; record.address = '测试地址'; record.status = 'approved' }; puts Pharma::OfferMatcher.new.call(drug_master: Pharma::DrugMaster.first, pharmacy: pharmacy, quantity: 10, province: '上海市', city: '上海市').size"
```

Expected: output is `0` because the temporary pharmacy has no approved license. This confirms eligibility checks are active.

- [ ] **Step 6: Run final verification**

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec
docker compose -f docker-compose.dev.yml exec web bin/rails db:migrate:status
curl -fsS http://localhost:3000/up
```

Expected: full RSpec suite passes, migrations are up, and health check succeeds.

- [ ] **Step 7: Commit seed and README updates**

Run:

```bash
git add db/seeds.rb db/seeds/pharma_demo.rb README.md
git commit -m "docs: add pharma development seed notes"
```

Expected: a commit is created for seeds and local development notes.

## Plan Self-Review

- Spec coverage: This plan covers the first implementation slice of the approved design: Spree backend, pharmacy/supplier identities, licenses, warehouses, drug master data, offers, regions, batch stock, supplier visibility, offer matching, and allocation/fulfillment records. It does not cover storefront screens, admin UI, supplier self-service, invoices, settlements, or traceability automation; those are explicitly later phases in the spec.
- Placeholder scan: The plan has no open placeholder markers or vague implementation steps. Each code-writing step includes exact file paths and code blocks.
- Type consistency: The plan consistently uses the `Pharma` namespace, `pharma_` table prefix, `supplier_warehouse` association name, string statuses, and `supplier_visibility_mode` values `hidden`, `partial`, and `visible`.
