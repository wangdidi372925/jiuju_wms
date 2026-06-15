# Supplier Fulfillment Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a tested admin workflow for moving supplier fulfillments through picking, shipped, received, and canceled states while keeping related order allocations synchronized.

**Architecture:** Put transition rules in `Pharma::SupplierFulfillmentWorkflow`; keep `SupplierFulfillmentsController` thin; expose list, show, and transition endpoints under existing admin API auth.

**Tech Stack:** Rails 8.1, RSpec service/request specs, RuboCop.

---

## File Structure

- `app/services/pharma/supplier_fulfillment_workflow.rb`: fulfillment state transitions and allocation sync.
- `app/controllers/pharma/admin/api/v1/supplier_fulfillments_controller.rb`: list, show, transition API.
- `config/routes.rb`: admin fulfillment routes.
- `spec/services/pharma/supplier_fulfillment_workflow_spec.rb`: workflow behavior.
- `spec/requests/pharma/admin/api/v1/supplier_fulfillments_spec.rb`: API behavior.

### Task 1: Add Supplier Fulfillment Workflow

- [ ] Write service specs for start picking, ship, receive, cancel, and invalid transitions.
- [ ] Run specs and confirm missing workflow behavior.
- [ ] Implement `Pharma::SupplierFulfillmentWorkflow`.
- [ ] Run service specs.
- [ ] Commit `feat: add supplier fulfillment workflow`.

### Task 2: Add Admin Supplier Fulfillment API

- [ ] Write request specs for missing token, list, show, successful transition, and invalid transition.
- [ ] Run specs and confirm missing route/controller.
- [ ] Implement `SupplierFulfillmentsController`.
- [ ] Add routes.
- [ ] Run request specs, full RSpec, targeted RuboCop, and health check.
- [ ] Commit `feat: add supplier fulfillment admin api`.

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

- Spec coverage: service state rules and API paths are covered.
- Placeholder scan: no TBD/TODO or vague implementation instructions.
- Type consistency: statuses match existing `Pharma::SupplierFulfillment` and `Pharma::OrderAllocation` models.
