# frozen_string_literal: true

module Pharma
  module Ops
    class SupplierOffersController < BaseController
      before_action :load_offer_form_options, only: %i[new create edit update]

      def index
        @offers = Pharma::SupplierOffer.includes(:supplier, :supplier_warehouse, :drug_master).
                  order(created_at: :desc).
                  limit(100)
      end

      def show
        @offer = Pharma::SupplierOffer.
                 includes(:supplier, :supplier_warehouse, :drug_master, :supplier_offer_regions, :drug_batch_stocks).
                 find(params[:id])
      end

      def new
        @offer = Pharma::SupplierOffer.new(
          status: 'draft',
          min_order_quantity: 1,
          starts_at: Time.current,
          ends_at: 30.days.from_now
        )
      end

      def create
        @offer = Pharma::SupplierOffer.new(supplier_offer_params)

        if @offer.save
          redirect_to "/pharma/ops/supplier_offers/#{@offer.id}", notice: '报价已创建'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @offer = Pharma::SupplierOffer.find(params[:id])
      end

      def update
        @offer = Pharma::SupplierOffer.find(params[:id])

        if @offer.update(supplier_offer_params)
          redirect_to "/pharma/ops/supplier_offers/#{@offer.id}", notice: '报价已更新'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def supplier_offer_params
        params.require(:supplier_offer).permit(
          :supplier_id,
          :drug_master_id,
          :supplier_warehouse_id,
          :unit_price,
          :min_order_quantity,
          :max_order_quantity,
          :status,
          :starts_at,
          :ends_at
        )
      end

      def load_offer_form_options
        @suppliers = Pharma::Supplier.order(:name)
        @warehouses = Pharma::SupplierWarehouse.includes(:supplier).order(:name)
        @drugs = Pharma::DrugMaster.order(:common_name, :specification)
      end
    end
  end
end
