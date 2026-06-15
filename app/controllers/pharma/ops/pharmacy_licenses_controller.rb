# frozen_string_literal: true

module Pharma
  module Ops
    class PharmacyLicensesController < BaseController
      REVIEW_STATUSES = %w[approved rejected expired].freeze

      def review
        return redirect_back(fallback_location: '/pharma/ops/pharmacies', alert: '状态无效') unless REVIEW_STATUSES.include?(params[:status])

        license = Pharma::PharmacyLicense.includes(:pharmacy).find(params[:id])
        license.update!(status: params[:status])

        redirect_to "/pharma/ops/pharmacies/#{license.pharmacy_id}", notice: '药店资质审核状态已更新'
      end
    end
  end
end
