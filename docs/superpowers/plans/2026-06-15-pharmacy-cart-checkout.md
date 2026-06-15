# Pharmacy Cart Checkout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add pharmacy-facing cart and checkout APIs that create Spree orders, add matched drug offers as line items, and submit carts through the existing pharma allocation flow.

**Architecture:** Put cart lifecycle rules in `Pharma::PharmacyCartService`; keep `Pharma::Api::V1::CartsController` thin. Use `Spree::Order` as the cart record and `Spree::LineItem` as cart rows, with pharma identifiers stored in `private_metadata` until Spree product/variant integration is implemented.

**Tech Stack:** Rails 8.1, Spree 5.5 models, RSpec service/request specs, RuboCop.

---

## File Structure

- `app/services/pharma/pharmacy_cart_service.rb`: cart creation, item add, checkout, error handling.
- `app/controllers/pharma/api/v1/carts_controller.rb`: create, show, add item, checkout API.
- `config/routes.rb`: pharmacy cart routes.
- `spec/services/pharma/pharmacy_cart_service_spec.rb`: service behavior.
- `spec/requests/pharma/api/v1/carts_spec.rb`: API behavior.

### Task 1: Add Pharmacy Cart Service

- [ ] Write service specs for creating a cart, adding a matched drug item, rejecting unapproved pharmacies, rejecting empty checkout, and successful checkout.
- [ ] Run specs and confirm missing service behavior.
- [ ] Implement `Pharma::PharmacyCartService`.
- [ ] Run service specs and related allocation specs.
- [ ] Commit `feat: add pharmacy cart service`.

### Task 2: Add Pharmacy Cart API

- [ ] Write request specs for create cart, show cart, add item, checkout, and common errors.
- [ ] Run specs and confirm missing route/controller.
- [ ] Implement `Pharma::Api::V1::CartsController`.
- [ ] Add routes.
- [ ] Run request specs, full RSpec, targeted RuboCop, and health check.
- [ ] Commit `feat: add pharmacy cart api`.

### Final Verification

Run:

```bash
docker compose -f docker-compose.dev.yml exec web bundle exec rspec
docker compose -f docker-compose.dev.yml exec web bundle exec rubocop app/controllers/pharma app/models/pharma app/services/pharma spec/requests/pharma spec/services/pharma config/routes.rb
curl -fsS http://localhost:3000/up
```

Expected:

- RSpec exits 0.
- RuboCop exits 0.
- `/up` returns green health HTML.

## Plan Self-Review

- Spec coverage: service and API tasks cover create, show, add item, checkout, and error paths.
- Placeholder scan: no TBD/TODO or vague implementation instructions.
- Type consistency: service and controller use the same endpoint names, error codes, and metadata keys from the design.
