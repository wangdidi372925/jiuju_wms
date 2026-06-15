# Pharma Procurement API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first usable JSON API layer for pharmacy drug search, offer matching, supplier visibility configuration, and operator-driven order allocation.

**Architecture:** Keep HTTP concerns in small Rails controllers under `Pharma::Api::V1` and `Pharma::Admin::Api::V1`. Put allocation side effects in `Pharma::OrderAllocator` so controllers stay thin and service behavior is directly testable.

**Tech Stack:** Rails 8.1, Spree 5.5, PostgreSQL, RSpec request specs, RuboCop.

---

## File Structure

- `config/routes.rb`: add pharma API routes.
- `app/controllers/pharma/api/v1/base_controller.rb`: JSON error helpers for pharmacy-facing API.
- `app/controllers/pharma/api/v1/drugs_controller.rb`: drug search and offer matching endpoints.
- `app/controllers/pharma/admin/api/v1/base_controller.rb`: admin token authentication and JSON error helpers.
- `app/controllers/pharma/admin/api/v1/supplier_visibility_configs_controller.rb`: read/update current supplier visibility mode.
- `app/controllers/pharma/admin/api/v1/order_allocations_controller.rb`: create allocation through `Pharma::OrderAllocator`.
- `app/services/pharma/order_allocator.rb`: validates offer/stock/order input, locks stock, creates allocation and fulfillment in a transaction.
- `spec/requests/pharma/api/v1/drugs_spec.rb`: request specs for drug search and offer matching.
- `spec/requests/pharma/admin/api/v1/supplier_visibility_configs_spec.rb`: request specs for admin visibility config.
- `spec/requests/pharma/admin/api/v1/order_allocations_spec.rb`: request specs for admin allocation endpoint.
- `spec/services/pharma/order_allocator_spec.rb`: service specs for allocation transaction behavior.

### Task 1: Add Drug Search and Offer Matching API

- [ ] Write request specs for `GET /pharma/api/v1/drugs` and `GET /pharma/api/v1/drugs/:id/offers`.
- [ ] Run the request specs and confirm routing/controller constants fail.
- [ ] Add pharmacy API base controller and drugs controller.
- [ ] Add routes.
- [ ] Run request specs and pharma specs.
- [ ] Commit `feat: add pharma drug offer api`.

### Task 2: Add Admin Supplier Visibility API

- [ ] Write request specs for missing token, reading current mode, updating mode, and invalid mode.
- [ ] Run specs and confirm controller route is missing.
- [ ] Add admin API base controller with token authentication.
- [ ] Add supplier visibility config controller and routes.
- [ ] Run request specs and pharma specs.
- [ ] Commit `feat: add pharma visibility admin api`.

### Task 3: Add Order Allocator Service

- [ ] Write service specs for successful allocation, insufficient stock, and line item/order mismatch.
- [ ] Run specs and confirm service constant is missing.
- [ ] Implement `Pharma::OrderAllocator`.
- [ ] Run service specs and pharma specs.
- [ ] Commit `feat: add pharma order allocator`.

### Task 4: Add Admin Order Allocation API

- [ ] Write request specs for missing token, successful allocation, missing records, and insufficient stock.
- [ ] Run specs and confirm route/controller is missing.
- [ ] Add order allocations controller and routes.
- [ ] Run request specs, service specs, full RSpec, and targeted RuboCop.
- [ ] Commit `feat: add pharma allocation admin api`.

### Final Verification

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec
docker compose -f docker-compose.dev.yml exec web bundle exec rubocop app/controllers/pharma app/services/pharma spec/requests/pharma spec/services/pharma config/routes.rb
curl -fsS http://localhost:3000/up
```

Expected:

- RSpec exits 0.
- RuboCop exits 0.
- `/up` returns the green health HTML.

## Plan Self-Review

- Spec coverage: covers all endpoints and service in `2026-06-15-pharma-procurement-api-design.md`.
- Placeholder scan: no TBD/TODO or vague future work inside this implementation slice.
- Type consistency: controllers, routes, service, and specs use the same `Pharma` names and existing model names.
