# frozen_string_literal: true

module Pharma
  module Admin
    module Api
      module V1
        class InventoryImportsController < BaseController
          def create
            return render_error(:unprocessable_entity, 'missing_file', 'inventory xlsx file is required') if uploaded_file.blank?
            return render_error(:unprocessable_entity, 'unsupported_file', 'only .xlsx files are supported') unless xlsx_upload?

            import = Pharma::InventoryImportProcessor.new.call(
              file: uploaded_file,
              filename: uploaded_file.original_filename
            )

            render json: { data: inventory_import_payload(import) }, status: :created
          end

          def show
            import = Pharma::InventoryImport.find(params[:id])

            render json: { data: inventory_import_payload(import) }
          end

          private

          def uploaded_file
            params[:file]
          end

          def xlsx_upload?
            File.extname(uploaded_file.original_filename.to_s).casecmp('.xlsx').zero?
          end

          def inventory_import_payload(import)
            {
              id: import.id,
              original_filename: import.original_filename,
              status: import.status,
              total_rows: import.total_rows,
              success_rows: import.success_rows,
              failed_rows: import.failed_rows,
              error_details: import.error_details,
              created_at: import.created_at.iso8601,
              updated_at: import.updated_at.iso8601
            }
          end
        end
      end
    end
  end
end
