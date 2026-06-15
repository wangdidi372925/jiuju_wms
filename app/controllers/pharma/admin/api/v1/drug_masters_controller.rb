# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class DrugMastersController < BaseController
          DEFAULT_LIMIT = 50

          def index
            drugs = Pharma::DrugMaster.order(created_at: :desc).limit(DEFAULT_LIMIT)

            render json: { data: drugs.map { |drug| drug_payload(drug) } }
          end

          def show
            drug = Pharma::DrugMaster.find(params[:id])

            render json: { data: drug_payload(drug) }
          end

          def create
            drug = Pharma::DrugMaster.create!(drug_params)

            render json: { data: drug_payload(drug) }, status: :created
          end

          def update
            drug = Pharma::DrugMaster.find(params[:id])
            drug.update!(drug_params)

            render json: { data: drug_payload(drug) }
          end

          private

          def drug_params
            params.permit(
              :common_name,
              :trade_name,
              :specification,
              :dosage_form,
              :manufacturer,
              :approval_number,
              :package_unit,
              :prescription_required,
              :storage_condition,
              :temperature_control,
              :status
            )
          end

          def drug_payload(drug)
            {
              id: drug.id,
              common_name: drug.common_name,
              trade_name: drug.trade_name,
              specification: drug.specification,
              dosage_form: drug.dosage_form,
              manufacturer: drug.manufacturer,
              approval_number: drug.approval_number,
              package_unit: drug.package_unit,
              prescription_required: drug.prescription_required,
              storage_condition: drug.storage_condition,
              temperature_control: drug.temperature_control,
              status: drug.status,
              display_name: drug.display_name
            }
          end
        end
      end
    end
  end
end
