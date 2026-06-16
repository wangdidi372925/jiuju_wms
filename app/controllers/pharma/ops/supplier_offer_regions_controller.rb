# frozen_string_literal: true

module Pharma
  module Ops
    class SupplierOfferRegionsController < BaseController
      def new
        @offer = Pharma::SupplierOffer.find(params[:supplier_offer_id])
        @region = @offer.supplier_offer_regions.new(status: 'active', delivery_days: 3)
      end

      def create
        @offer = Pharma::SupplierOffer.find(params[:supplier_offer_id])
        @region = @offer.supplier_offer_regions.new(region_params)

        if @region.save
          redirect_to "/pharma/ops/supplier_offers/#{@offer.id}", notice: '可售区域已创建'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @region = Pharma::SupplierOfferRegion.includes(:supplier_offer).find(params[:id])
        @offer = @region.supplier_offer
      end

      def update
        @region = Pharma::SupplierOfferRegion.includes(:supplier_offer).find(params[:id])
        @offer = @region.supplier_offer

        if @region.update(region_params)
          redirect_to "/pharma/ops/supplier_offers/#{@offer.id}", notice: '可售区域已更新'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def region_params
        params.require(:supplier_offer_region).permit(:province, :city, :district, :delivery_days, :status)
      end
    end
  end
end
