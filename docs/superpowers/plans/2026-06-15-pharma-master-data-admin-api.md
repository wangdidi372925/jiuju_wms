# Pharma Master Data Admin API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add admin JSON APIs for maintaining drug masters, suppliers, supplier licenses, warehouses, offers, regions, and batch stock.

**Architecture:** Use focused Rails API controllers under `Pharma::Admin::Api::V1`. Keep each controller thin: permit params, call ActiveRecord create/update, render compact JSON payloads, and rely on existing model validations.

**Tech Stack:** Rails 8.1, Spree 5.5, PostgreSQL, RSpec request specs, RuboCop.

---

## File Structure

- `config/routes.rb`: add admin routes for master data resources.
- `app/controllers/pharma/admin/api/v1/base_controller.rb`: add validation error handling shared by admin controllers.
- `app/controllers/pharma/admin/api/v1/drug_masters_controller.rb`: index/show/create/update drug master data.
- `app/controllers/pharma/admin/api/v1/suppliers_controller.rb`: index/show/create/update suppliers.
- `app/controllers/pharma/admin/api/v1/supplier_licenses_controller.rb`: create/update supplier licenses.
- `app/controllers/pharma/admin/api/v1/supplier_warehouses_controller.rb`: create/update supplier warehouses.
- `app/controllers/pharma/admin/api/v1/supplier_offers_controller.rb`: create/update supplier offers and render nested regions/stocks.
- `app/controllers/pharma/admin/api/v1/supplier_offer_regions_controller.rb`: create/update offer regions.
- `app/controllers/pharma/admin/api/v1/drug_batch_stocks_controller.rb`: create/update batch stock.
- `spec/requests/pharma/admin/api/v1/master_data_spec.rb`: request specs for all master data endpoints.

### Task 1: Drug Master Admin API

- [ ] Write request specs for missing token, create, update, index, and show.
- [ ] Run specs and confirm missing routes/controllers.
- [ ] Implement shared admin validation error handling.
- [ ] Implement `DrugMastersController`.
- [ ] Add routes.
- [ ] Run specs.
- [ ] Commit `feat: add drug master admin api`.

### Task 2: Supplier, License, and Warehouse Admin API

- [ ] Write request specs for supplier create/update/show, supplier license create/update, supplier warehouse create/update.
- [ ] Run specs and confirm missing routes/controllers.
- [ ] Implement suppliers, supplier licenses, and supplier warehouses controllers.
- [ ] Add routes.
- [ ] Run specs.
- [ ] Commit `feat: add supplier master admin api`.

### Task 3: Offer, Region, and Batch Stock Admin API

- [ ] Write request specs for offer create/update/show, region create/update, stock create/update.
- [ ] Run specs and confirm missing routes/controllers.
- [ ] Implement supplier offers, offer regions, and drug batch stock controllers.
- [ ] Add routes.
- [ ] Run specs.
- [ ] Commit `feat: add offer stock admin api`.

### Final Verification

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec
docker compose -f docker-compose.dev.yml exec web bundle exec rubocop app/controllers/pharma spec/requests/pharma config/routes.rb
curl -fsS http://localhost:3000/up
```

Expected:

- RSpec exits 0.
- RuboCop exits 0.
- `/up` returns green health HTML.

## Plan Self-Review

- Spec coverage: covers all endpoints in `2026-06-15-pharma-master-data-admin-api-design.md`.
- Placeholder scan: no TBD/TODO or vague implementation instructions.
- Type consistency: route names and controller names match existing `Pharma::Admin::Api::V1` structure.
