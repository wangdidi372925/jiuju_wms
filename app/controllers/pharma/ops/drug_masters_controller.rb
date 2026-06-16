# frozen_string_literal: true

module Pharma
  module Ops
    class DrugMastersController < BaseController
      def index
        @query = params[:query].to_s.strip
        @drugs = Pharma::DrugMaster.order(created_at: :desc).limit(100)
        @drugs = @drugs.where(search_condition, query: "%#{Pharma::DrugMaster.sanitize_sql_like(@query)}%") if @query.present?
      end

      def new
        @drug = Pharma::DrugMaster.new(status: 'active', temperature_control: 'normal', package_unit: '盒')
      end

      def create
        @drug = Pharma::DrugMaster.new(drug_params)

        if @drug.save
          redirect_to "/pharma/ops/drug_masters/#{@drug.id}/edit", notice: '药品已创建'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @drug = Pharma::DrugMaster.find(params[:id])
      end

      def update
        @drug = Pharma::DrugMaster.find(params[:id])

        if @drug.update(drug_params)
          redirect_to "/pharma/ops/drug_masters/#{@drug.id}/edit", notice: '药品已更新'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def drug_params
        params.require(:drug_master).permit(
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

      def search_condition
        <<~SQL.squish
          common_name ILIKE :query
          OR trade_name ILIKE :query
          OR specification ILIKE :query
          OR manufacturer ILIKE :query
          OR approval_number ILIKE :query
        SQL
      end
    end
  end
end
