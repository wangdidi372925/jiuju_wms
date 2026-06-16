# frozen_string_literal: true

module Pharma
  module Ops
    class SupplierLicensesController < BaseController
      def new
        @supplier = Pharma::Supplier.find(params[:supplier_id])
        @license = @supplier.supplier_licenses.new(status: 'pending')
      end

      def create
        @supplier = Pharma::Supplier.find(params[:supplier_id])
        @license = @supplier.supplier_licenses.new(supplier_license_params)

        if @license.save
          redirect_to "/pharma/ops/suppliers/#{@supplier.id}", notice: '供应商资质已创建'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @license = Pharma::SupplierLicense.includes(:supplier).find(params[:id])
        @supplier = @license.supplier
      end

      def update
        @license = Pharma::SupplierLicense.includes(:supplier).find(params[:id])
        @supplier = @license.supplier

        if @license.update(supplier_license_params)
          redirect_to "/pharma/ops/suppliers/#{@supplier.id}", notice: '供应商资质已更新'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def supplier_license_params
        params.require(:supplier_license).permit(:license_type, :license_no, :status, :starts_on, :expires_on)
      end
    end
  end
end
