# frozen_string_literal: true

module Pharma
  module Ops
    class SuppliersController < BaseController
      def index
        @status = params[:status].presence
        @suppliers = Pharma::Supplier.order(created_at: :desc).limit(100)
        @suppliers = @suppliers.where(status: @status) if @status.present?
      end

      def show
        @supplier = Pharma::Supplier.includes(:supplier_licenses, :supplier_warehouses).find(params[:id])
      end

      def new
        @supplier = Pharma::Supplier.new(status: 'pending', priority: 0)
      end

      def create
        @supplier = Pharma::Supplier.new(supplier_params)

        if @supplier.save
          redirect_to "/pharma/ops/suppliers/#{@supplier.id}", notice: '货盘方已创建'
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @supplier = Pharma::Supplier.find(params[:id])
      end

      def update
        @supplier = Pharma::Supplier.find(params[:id])

        if @supplier.update(supplier_params)
          redirect_to "/pharma/ops/suppliers/#{@supplier.id}", notice: '货盘方已更新'
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def supplier_params
        params.require(:supplier).permit(:name, :code, :contact_name, :contact_phone, :province, :city, :status, :priority)
      end
    end
  end
end
