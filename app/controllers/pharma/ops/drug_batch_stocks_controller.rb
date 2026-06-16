# frozen_string_literal: true

module Pharma
  module Ops
    class DrugBatchStocksController < BaseController
      def new
        @offer = Pharma::SupplierOffer.includes(:supplier, :supplier_warehouse, :drug_master).find(params[:supplier_offer_id])
        @stock = @offer.drug_batch_stocks.new(
          supplier: @offer.supplier,
          supplier_warehouse: @offer.supplier_warehouse,
          drug_master: @offer.drug_master,
          status: 'active',
          quantity_locked: 0
        )
      end

      def create
        @offer = Pharma::SupplierOffer.includes(:supplier, :supplier_warehouse, :drug_master).find(params[:supplier_offer_id])
        @stock = @offer.drug_batch_stocks.new(stock_params.merge(
                                                supplier: @offer.supplier,
                                                supplier_warehouse: @offer.supplier_warehouse,
                                                drug_master: @offer.drug_master
                                              ))

        if @stock.save
          redirect_to "/pharma/ops/supplier_offers/#{@offer.id}", notice: '批号库存已创建'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @stock = Pharma::DrugBatchStock.includes(:supplier_offer).find(params[:id])
        @offer = @stock.supplier_offer
      end

      def update
        @stock = Pharma::DrugBatchStock.includes(:supplier_offer).find(params[:id])
        @offer = @stock.supplier_offer

        if @stock.update(stock_params)
          redirect_to "/pharma/ops/supplier_offers/#{@offer.id}", notice: '批号库存已更新'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def stock_params
        params.require(:drug_batch_stock).permit(:batch_no, :expiry_date, :quantity_on_hand, :quantity_locked, :status)
      end
    end
  end
end
