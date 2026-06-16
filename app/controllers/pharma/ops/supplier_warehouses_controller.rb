# frozen_string_literal: true

module Pharma
  module Ops
    class SupplierWarehousesController < BaseController
      def new
        @supplier = Pharma::Supplier.find(params[:supplier_id])
        @warehouse = @supplier.supplier_warehouses.new(status: 'active')
      end

      def create
        @supplier = Pharma::Supplier.find(params[:supplier_id])
        @warehouse = @supplier.supplier_warehouses.new(supplier_warehouse_params)

        if @warehouse.save
          redirect_to "/pharma/ops/suppliers/#{@supplier.id}", notice: '供应商仓库已创建'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @warehouse = Pharma::SupplierWarehouse.includes(:supplier).find(params[:id])
        @supplier = @warehouse.supplier
      end

      def update
        @warehouse = Pharma::SupplierWarehouse.includes(:supplier).find(params[:id])
        @supplier = @warehouse.supplier

        if @warehouse.update(supplier_warehouse_params)
          redirect_to "/pharma/ops/suppliers/#{@supplier.id}", notice: '供应商仓库已更新'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def supplier_warehouse_params
        params.require(:supplier_warehouse).permit(
          :name,
          :code,
          :province,
          :city,
          :district,
          :address,
          :cold_chain_enabled,
          :status
        )
      end
    end
  end
end
