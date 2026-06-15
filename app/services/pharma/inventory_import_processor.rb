# frozen_string_literal: true

module Pharma
  class InventoryImportProcessor
    class HeaderError < StandardError; end
    class RowError < StandardError; end

    HEADER_MAP = {
      '供应商编码' => :supplier_code,
      '供应商名称' => :supplier_name,
      '供应商联系人' => :supplier_contact_name,
      '供应商电话' => :supplier_contact_phone,
      '供应商省' => :supplier_province,
      '供应商市' => :supplier_city,
      '仓库编码' => :warehouse_code,
      '仓库名称' => :warehouse_name,
      '仓库省' => :warehouse_province,
      '仓库市' => :warehouse_city,
      '仓库区' => :warehouse_district,
      '仓库地址' => :warehouse_address,
      '通用名' => :common_name,
      '商品名' => :trade_name,
      '规格' => :specification,
      '剂型' => :dosage_form,
      '生产厂家' => :manufacturer,
      '批准文号' => :approval_number,
      '包装单位' => :package_unit,
      '是否处方' => :prescription_required,
      '储存条件' => :storage_condition,
      '温控' => :temperature_control,
      '单价' => :unit_price,
      '起订量' => :min_order_quantity,
      '限购量' => :max_order_quantity,
      '报价状态' => :offer_status,
      '报价开始' => :starts_at,
      '报价结束' => :ends_at,
      '可售省' => :sale_province,
      '可售市' => :sale_city,
      '可售区' => :sale_district,
      '配送天数' => :delivery_days,
      '批号' => :batch_no,
      '效期' => :expiry_date,
      '库存' => :quantity_on_hand,
      '锁定库存' => :quantity_locked
    }.freeze

    REQUIRED_ATTRIBUTES = {
      supplier_code: '供应商编码',
      supplier_name: '供应商名称',
      supplier_contact_name: '供应商联系人',
      supplier_contact_phone: '供应商电话',
      supplier_province: '供应商省',
      supplier_city: '供应商市',
      warehouse_code: '仓库编码',
      warehouse_name: '仓库名称',
      warehouse_province: '仓库省',
      warehouse_city: '仓库市',
      warehouse_address: '仓库地址',
      common_name: '通用名',
      specification: '规格',
      dosage_form: '剂型',
      manufacturer: '生产厂家',
      approval_number: '批准文号',
      package_unit: '包装单位',
      storage_condition: '储存条件',
      temperature_control: '温控',
      unit_price: '单价',
      min_order_quantity: '起订量',
      starts_at: '报价开始',
      ends_at: '报价结束',
      sale_province: '可售省',
      delivery_days: '配送天数',
      batch_no: '批号',
      expiry_date: '效期',
      quantity_on_hand: '库存'
    }.freeze

    TEMPERATURE_CONTROL_MAP = {
      '常温' => 'normal',
      '普通' => 'normal',
      'normal' => 'normal',
      '阴凉' => 'cool',
      '冷藏' => 'cool',
      'cool' => 'cool',
      '冷链' => 'cold_chain',
      'cold_chain' => 'cold_chain'
    }.freeze

    OFFER_STATUS_MAP = {
      '草稿' => 'draft',
      '待审核' => 'draft',
      'draft' => 'draft',
      '已审核' => 'approved',
      '已上架' => 'approved',
      '可售' => 'approved',
      'approved' => 'approved',
      '暂停' => 'suspended',
      'suspended' => 'suspended',
      '过期' => 'expired',
      'expired' => 'expired'
    }.freeze

    TRUE_VALUES = %w[是 true TRUE 1 yes YES y Y].freeze
    FALSE_VALUES = %w[否 false FALSE 0 no NO n N].freeze

    def call(file:, filename:)
      import = Pharma::InventoryImport.create!(original_filename: filename.presence || 'inventory.xlsx')

      process_workbook(import, file)
    rescue Pharma::XlsxReader::ParseError, HeaderError => e
      import.update!(
        status: 'failed',
        total_rows: 0,
        success_rows: 0,
        failed_rows: 0,
        error_details: [error_detail(nil, e.message)]
      )
      import
    end

    private

    def process_workbook(import, file)
      rows = Pharma::XlsxReader.new(file).rows
      headers = extract_headers(rows)
      error_details = []
      total_rows = 0
      success_rows = 0

      rows.drop(1).each_with_index do |row, index|
        next if blank_row?(row)

        total_rows += 1
        row_number = index + 2

        begin
          process_row!(attributes_for(headers, row))
          success_rows += 1
        rescue StandardError => e
          error_details << error_detail(row_number, e.message)
        end
      end

      import.update!(
        status: import_status(failed_rows: error_details.size),
        total_rows: total_rows,
        success_rows: success_rows,
        failed_rows: error_details.size,
        error_details: error_details
      )

      import
    end

    def extract_headers(rows)
      raise HeaderError, 'Excel 文件不能为空' if rows.blank?

      headers = rows.first.map { |header| header.to_s.strip }
      missing_headers = REQUIRED_ATTRIBUTES.values - headers
      raise HeaderError, "缺少必填列：#{missing_headers.join('、')}" if missing_headers.any?

      headers
    end

    def process_row!(attributes)
      validate_required_attributes!(attributes)

      ActiveRecord::Base.transaction do
        supplier = upsert_supplier(attributes)
        warehouse = upsert_warehouse(attributes, supplier)
        drug = upsert_drug(attributes)
        offer = upsert_offer(attributes, supplier, warehouse, drug)

        upsert_region(attributes, offer)
        upsert_stock(attributes, supplier, warehouse, drug, offer)
      end
    end

    def validate_required_attributes!(attributes)
      missing_labels = REQUIRED_ATTRIBUTES.filter_map do |key, label|
        label if attributes[key].blank?
      end

      raise RowError, "#{missing_labels.join('、')}不能为空" if missing_labels.any?
    end

    def upsert_supplier(attributes)
      supplier = Pharma::Supplier.find_or_initialize_by(code: attributes.fetch(:supplier_code))
      supplier.assign_attributes(
        name: attributes.fetch(:supplier_name),
        contact_name: attributes.fetch(:supplier_contact_name),
        contact_phone: attributes.fetch(:supplier_contact_phone),
        province: attributes.fetch(:supplier_province),
        city: attributes.fetch(:supplier_city)
      )
      supplier.status = 'pending' if supplier.status.blank?
      supplier.priority = 0 if supplier.priority.blank?
      supplier.save!
      supplier
    end

    def upsert_warehouse(attributes, supplier)
      warehouse = Pharma::SupplierWarehouse.find_or_initialize_by(code: attributes.fetch(:warehouse_code))
      raise RowError, "仓库编码#{warehouse.code}已属于其他供应商" if warehouse.persisted? && warehouse.supplier_id != supplier.id

      warehouse.assign_attributes(
        supplier: supplier,
        name: attributes.fetch(:warehouse_name),
        province: attributes.fetch(:warehouse_province),
        city: attributes.fetch(:warehouse_city),
        district: blank_to_nil(attributes[:warehouse_district]),
        address: attributes.fetch(:warehouse_address),
        status: warehouse.status.presence || 'active'
      )
      warehouse.cold_chain_enabled = true if normalized_temperature_control(attributes.fetch(:temperature_control)) == 'cold_chain'
      warehouse.save!
      warehouse
    end

    def upsert_drug(attributes)
      drug = Pharma::DrugMaster.find_or_initialize_by(approval_number: attributes.fetch(:approval_number))
      drug.assign_attributes(
        common_name: attributes.fetch(:common_name),
        trade_name: blank_to_nil(attributes[:trade_name]),
        specification: attributes.fetch(:specification),
        dosage_form: attributes.fetch(:dosage_form),
        manufacturer: attributes.fetch(:manufacturer),
        package_unit: attributes.fetch(:package_unit),
        prescription_required: boolean_value(attributes[:prescription_required]),
        storage_condition: attributes.fetch(:storage_condition),
        temperature_control: normalized_temperature_control(attributes.fetch(:temperature_control)),
        status: drug.status.presence || 'active'
      )
      drug.save!
      drug
    end

    def upsert_offer(attributes, supplier, warehouse, drug)
      offer = Pharma::SupplierOffer.find_or_initialize_by(
        supplier: supplier,
        drug_master: drug,
        supplier_warehouse: warehouse
      )
      offer.assign_attributes(
        unit_price: decimal_value(attributes.fetch(:unit_price), '单价'),
        min_order_quantity: integer_value(attributes.fetch(:min_order_quantity), '起订量'),
        max_order_quantity: optional_integer_value(attributes[:max_order_quantity], '限购量'),
        status: normalized_offer_status(attributes[:offer_status], offer.status),
        starts_at: time_value(attributes.fetch(:starts_at), '报价开始'),
        ends_at: time_value(attributes.fetch(:ends_at), '报价结束')
      )
      offer.save!
      offer
    end

    def upsert_region(attributes, offer)
      region = Pharma::SupplierOfferRegion.find_or_initialize_by(
        supplier_offer: offer,
        province: attributes.fetch(:sale_province),
        city: blank_to_nil(attributes[:sale_city]),
        district: blank_to_nil(attributes[:sale_district])
      )
      region.assign_attributes(
        delivery_days: integer_value(attributes.fetch(:delivery_days), '配送天数'),
        status: region.status.presence || 'active'
      )
      region.save!
      region
    end

    def upsert_stock(attributes, supplier, warehouse, drug, offer)
      stock = Pharma::DrugBatchStock.find_or_initialize_by(
        supplier: supplier,
        supplier_warehouse: warehouse,
        drug_master: drug,
        batch_no: attributes.fetch(:batch_no)
      )
      stock.assign_attributes(
        supplier_offer: offer,
        expiry_date: date_value(attributes.fetch(:expiry_date), '效期'),
        quantity_on_hand: integer_value(attributes.fetch(:quantity_on_hand), '库存'),
        quantity_locked: optional_integer_value(attributes[:quantity_locked], '锁定库存') || 0,
        status: stock.status.presence || 'active'
      )
      stock.save!
      stock
    end

    def attributes_for(headers, row)
      headers.each_with_object({}).with_index do |(header, attributes), index|
        key = HEADER_MAP[header]
        attributes[key] = row[index].to_s.strip if key
      end
    end

    def blank_row?(row)
      row.all? { |value| value.to_s.strip.blank? }
    end

    def import_status(failed_rows:)
      failed_rows.zero? ? 'completed' : 'completed_with_errors'
    end

    def normalized_temperature_control(value)
      normalized = TEMPERATURE_CONTROL_MAP[value.to_s.strip]
      return normalized if normalized.present?

      raise RowError, "温控不支持：#{value}"
    end

    def normalized_offer_status(value, current_status)
      return current_status.presence || 'draft' if value.blank?

      normalized = OFFER_STATUS_MAP[value.to_s.strip]
      return normalized if normalized.present?

      raise RowError, "报价状态不支持：#{value}"
    end

    def boolean_value(value)
      return false if value.blank?
      return true if TRUE_VALUES.include?(value.to_s.strip)
      return false if FALSE_VALUES.include?(value.to_s.strip)

      raise RowError, "是否处方不支持：#{value}"
    end

    def decimal_value(value, label)
      BigDecimal(value.to_s)
    rescue ArgumentError
      raise RowError, "#{label}必须是数字"
    end

    def integer_value(value, label)
      decimal = decimal_value(value, label)
      raise RowError, "#{label}必须是整数" unless decimal.frac.zero?

      decimal.to_i
    end

    def optional_integer_value(value, label)
      return nil if value.blank?

      integer_value(value, label)
    end

    def date_value(value, label)
      Date.parse(value.to_s)
    rescue ArgumentError
      raise RowError, "#{label}格式不正确"
    end

    def time_value(value, label)
      Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      raise RowError, "#{label}格式不正确"
    end

    def blank_to_nil(value)
      value.presence
    end

    def error_detail(row, message)
      { row: row, message: message }
    end
  end
end
