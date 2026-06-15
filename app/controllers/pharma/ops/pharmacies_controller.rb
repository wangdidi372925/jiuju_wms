# frozen_string_literal: true

module Pharma
  module Ops
    class PharmaciesController < BaseController
      REVIEW_STATUSES = %w[approved rejected suspended].freeze

      def index
        @status = params[:status].presence
        @pharmacies = Pharma::Pharmacy.includes(:pharmacy_licenses).order(created_at: :desc)
        @pharmacies = @pharmacies.where(status: @status) if @status.present?
      end

      def show
        @pharmacy = Pharma::Pharmacy.includes(:pharmacy_licenses).find(params[:id])
      end

      def review
        return redirect_back(fallback_location: '/pharma/ops/pharmacies', alert: '状态无效') unless REVIEW_STATUSES.include?(params[:status])

        pharmacy = Pharma::Pharmacy.find(params[:id])
        pharmacy.update!(status: params[:status])

        redirect_to "/pharma/ops/pharmacies/#{pharmacy.id}", notice: '药店审核状态已更新'
      end
    end
  end
end
