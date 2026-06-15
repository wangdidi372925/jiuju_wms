# frozen_string_literal: true

require 'rails_helper'
require 'support/pharma_xlsx_fixture'

RSpec.describe 'Pharma admin inventory imports API', type: :request do
  include PharmaXlsxFixture

  def inventory_headers
    [
      '供应商编码', '供应商名称', '供应商联系人', '供应商电话', '供应商省', '供应商市',
      '仓库编码', '仓库名称', '仓库省', '仓库市', '仓库区', '仓库地址',
      '通用名', '商品名', '规格', '剂型', '生产厂家', '批准文号', '包装单位',
      '是否处方', '储存条件', '温控', '单价', '起订量', '限购量',
      '报价状态', '报价开始', '报价结束', '可售省', '可售市', '可售区',
      '配送天数', '批号', '效期', '库存', '锁定库存'
    ]
  end

  def xlsx_mime
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  end

  def json_body
    JSON.parse(response.body)
  end

  def admin_headers
    { 'X-Pharma-Admin-Token' => 'dev-admin-token' }
  end

  def valid_row
    [
      'SUP-API-IMPORT-001',
      '华东医药供货有限公司',
      '李经理',
      '13900009001',
      '上海市',
      '上海市',
      'WH-API-IMPORT-001',
      '上海中心仓',
      '上海市',
      '上海市',
      '浦东新区',
      '仓库路 9 号',
      '阿莫西林胶囊',
      '阿莫西林',
      '0.25g*24粒',
      '胶囊剂',
      '示例制药有限公司',
      '国药准字HAPIIMPORT001',
      '盒',
      '是',
      '常温',
      '常温',
      '8.5',
      '10',
      '500',
      'approved',
      '2026-06-01',
      '2026-12-31',
      '上海市',
      '上海市',
      '浦东新区',
      '1',
      'BATCH-API-IMPORT-001',
      '2028-06-01',
      '300',
      '20'
    ]
  end

  def upload_for(file, mime: xlsx_mime)
    Rack::Test::UploadedFile.new(file.path, mime)
  end

  it 'requires admin token' do
    post '/pharma/admin/api/v1/inventory_imports'

    expect(response).to have_http_status(:unauthorized)
    expect(json_body).to include('error' => 'unauthorized')
  end

  it 'rejects requests without a file' do
    post '/pharma/admin/api/v1/inventory_imports', headers: admin_headers

    expect(response).to have_http_status(422)
    expect(json_body).to include('error' => 'missing_file')
  end

  it 'rejects non-xlsx uploads' do
    file = Tempfile.new(['inventory', '.csv'])
    file.write('bad,workbook')
    file.rewind

    post '/pharma/admin/api/v1/inventory_imports',
         params: { file: upload_for(file, mime: 'text/csv') },
         headers: admin_headers

    expect(response).to have_http_status(422)
    expect(json_body).to include('error' => 'unsupported_file')
  ensure
    file&.close!
  end

  it 'uploads a workbook and shows the import result' do
    file = build_xlsx([inventory_headers, valid_row])

    post '/pharma/admin/api/v1/inventory_imports',
         params: { file: upload_for(file) },
         headers: admin_headers

    expect(response).to have_http_status(:created)
    data = json_body.fetch('data')
    expect(data).to include(
      'status' => 'completed',
      'total_rows' => 1,
      'success_rows' => 1,
      'failed_rows' => 0,
      'error_details' => []
    )

    get "/pharma/admin/api/v1/inventory_imports/#{data.fetch('id')}", headers: admin_headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to include('id' => data.fetch('id'), 'status' => 'completed')
  ensure
    file&.close!
  end
end
