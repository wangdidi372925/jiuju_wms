# Inventory Excel Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add synchronous `.xlsx` inventory import for supplier offers, regions, and batch stock.

**Architecture:** Store every import attempt in `Pharma::InventoryImport`. Parse `.xlsx` with a small RubyZip-based reader, then process rows through `Pharma::InventoryImportProcessor`, keeping row transactions independent and controller logic thin.

**Tech Stack:** Rails 8.1, PostgreSQL JSONB, RubyZip, RSpec request/service specs, RuboCop.

---

## File Structure

- `db/migrate/20260615001000_create_pharma_inventory_imports.rb`: import records.
- `app/models/pharma/inventory_import.rb`: import status and error details.
- `app/services/pharma/xlsx_reader.rb`: minimal first-sheet `.xlsx` reader.
- `app/services/pharma/inventory_import_processor.rb`: row validation and upsert behavior.
- `app/controllers/pharma/admin/api/v1/inventory_imports_controller.rb`: upload and show imports.
- `config/routes.rb`: admin import routes.
- `spec/services/pharma/xlsx_reader_spec.rb`: parser behavior.
- `spec/services/pharma/inventory_import_processor_spec.rb`: import service behavior.
- `spec/requests/pharma/admin/api/v1/inventory_imports_spec.rb`: upload API behavior.

### Task 1: Add Import Record and XLSX Reader

- [ ] Write model/parser specs for import status defaults and `.xlsx` row extraction.
- [ ] Run specs and confirm missing model/service.
- [ ] Add migration and model.
- [ ] Add RubyZip-based `Pharma::XlsxReader`.
- [ ] Run migration and specs.
- [ ] Commit `feat: add inventory import record and xlsx reader`.

### Task 2: Add Inventory Import Processor

- [ ] Write service specs for successful row import, row-level validation failure, and invalid workbook failure.
- [ ] Run specs and confirm missing processor behavior.
- [ ] Implement `Pharma::InventoryImportProcessor`.
- [ ] Run service specs and pharma specs.
- [ ] Commit `feat: add inventory import processor`.

### Task 3: Add Admin Inventory Import API

- [ ] Write request specs for missing token, missing file, successful upload, and show.
- [ ] Run specs and confirm missing route/controller.
- [ ] Implement `InventoryImportsController`.
- [ ] Add routes.
- [ ] Run request specs, full RSpec, targeted RuboCop, and health check.
- [ ] Commit `feat: add inventory import admin api`.

### Final Verification

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bin/rails db:migrate
docker compose -f docker-compose.dev.yml exec web bundle exec rspec
docker compose -f docker-compose.dev.yml exec web bundle exec rubocop app/controllers/pharma app/models/pharma app/services/pharma spec/requests/pharma spec/services/pharma config/routes.rb
curl -fsS http://localhost:3000/up
```

Expected:

- Migrations are up.
- RSpec exits 0.
- RuboCop exits 0.
- `/up` returns green health HTML.

## Plan Self-Review

- Spec coverage: covers import record, parser, processor, upload API, and show API.
- Placeholder scan: no TBD/TODO or vague implementation instructions.
- Type consistency: statuses and column names match the design spec.
