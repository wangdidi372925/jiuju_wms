# frozen_string_literal: true

module Pharma
  module Ops
    class InventoryImportsController < BaseController
      def index
        @imports = Pharma::InventoryImport.order(created_at: :desc).limit(50)
      end

      def new
        @import = Pharma::InventoryImport.new
      end

      def create
        file = params.dig(:inventory_import, :file)
        return redirect_to('/pharma/ops/inventory_imports/new', alert: '请上传货盘 Excel 文件') if file.blank?
        return redirect_to('/pharma/ops/inventory_imports/new', alert: '仅支持 .xlsx 文件') unless xlsx_upload?(file)

        import = Pharma::InventoryImportProcessor.new.call(file: file, filename: file.original_filename)

        redirect_to "/pharma/ops/inventory_imports/#{import.id}", notice: '货盘导入已完成'
      end

      def show
        @import = Pharma::InventoryImport.find(params[:id])
        @recent_suppliers = Pharma::Supplier.order(created_at: :desc).limit(10)
      end

      private

      def xlsx_upload?(file)
        File.extname(file.original_filename.to_s).casecmp('.xlsx').zero?
      end
    end
  end
end
