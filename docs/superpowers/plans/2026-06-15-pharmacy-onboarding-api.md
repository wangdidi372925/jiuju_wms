# Pharmacy Onboarding API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON APIs for pharmacy registration, license submission, and platform review.

**Architecture:** Keep pharmacy-facing controllers under `Pharma::Api::V1` and platform controllers under `Pharma::Admin::Api::V1`. Reuse existing model validations and controller JSON error helpers.

**Tech Stack:** Rails 8.1, Spree 5.5, PostgreSQL, RSpec request specs, RuboCop.

---

## File Structure

- `config/routes.rb`: add public pharmacy/license routes and admin pharmacy/license review routes.
- `app/controllers/pharma/api/v1/pharmacies_controller.rb`: create pharmacy buyer records.
- `app/controllers/pharma/api/v1/pharmacy_licenses_controller.rb`: submit pharmacy license records.
- `app/controllers/pharma/admin/api/v1/pharmacies_controller.rb`: list/show/review pharmacy records.
- `app/controllers/pharma/admin/api/v1/pharmacy_licenses_controller.rb`: review pharmacy license records.
- `spec/requests/pharma/api/v1/pharmacies_spec.rb`: public onboarding request specs.
- `spec/requests/pharma/admin/api/v1/pharmacies_spec.rb`: admin review request specs.

### Task 1: Public Pharmacy Onboarding API

- [ ] Write request specs for pharmacy creation, duplicate code validation, license submission, and missing pharmacy.
- [ ] Run specs and confirm routes/controllers are missing.
- [ ] Implement `Pharma::Api::V1::PharmaciesController`.
- [ ] Implement `Pharma::Api::V1::PharmacyLicensesController`.
- [ ] Add routes.
- [ ] Run public onboarding specs and pharma request specs.
- [ ] Commit `feat: add pharmacy onboarding api`.

### Task 2: Admin Pharmacy Review API

- [ ] Write request specs for missing token, list, show, pharmacy review, invalid pharmacy status, license review, invalid license status, and purchase eligibility after approval.
- [ ] Run specs and confirm routes/controllers are missing.
- [ ] Implement `Pharma::Admin::Api::V1::PharmaciesController`.
- [ ] Implement `Pharma::Admin::Api::V1::PharmacyLicensesController`.
- [ ] Add routes.
- [ ] Run admin review specs and pharma request specs.
- [ ] Commit `feat: add pharmacy review admin api`.

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

- Spec coverage: covers all endpoints in `2026-06-15-pharmacy-onboarding-api-design.md`.
- Placeholder scan: no TBD/TODO or vague future work inside this implementation slice.
- Type consistency: controllers and specs use existing `Pharma::Pharmacy` and `Pharma::PharmacyLicense` model names and statuses.
