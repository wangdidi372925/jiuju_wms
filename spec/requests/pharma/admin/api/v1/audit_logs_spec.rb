# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pharma admin audit logs API', type: :request do
  def json_body
    JSON.parse(response.body)
  end

  def admin_client_headers(role:, name: "#{role} audit client")
    client, raw_token = Pharma::AdminApiClient.issue!(name: name, role: role)

    [{ 'X-Pharma-Admin-Token' => raw_token }, client]
  end

  def audit_log_for(client:, status:, options: {})
    Pharma::AdminAuditLog.create!(
      admin_api_client: client,
      actor_name: client.name,
      actor_role: options.fetch(:actor_role, client.role),
      request_method: status.to_i >= 400 ? 'POST' : 'GET',
      path: options.fetch(:path, '/pharma/admin/api/v1/suppliers'),
      controller_path: 'pharma/admin/api/v1/suppliers',
      action_name: status.to_i >= 400 ? 'create' : 'index',
      status: status,
      error_code: options[:error_code],
      request_params: {
        'code' => 'SUP-AUDIT-001',
        'password' => '[FILTERED]'
      },
      ip_address: '127.0.0.1',
      user_agent: 'RSpec',
      occurred_at: options.fetch(:occurred_at, Time.current)
    )
  end

  it 'lists audit logs with filters and pagination metadata' do
    headers, client = admin_client_headers(role: 'viewer', name: '审计查看客户端')
    matching_log = audit_log_for(
      client: client,
      status: 403,
      options: {
        error_code: 'forbidden',
        path: '/pharma/admin/api/v1/suppliers',
        occurred_at: 2.hours.ago
      }
    )
    audit_log_for(
      client: client,
      status: 200,
      options: {
        path: '/pharma/admin/api/v1/orders',
        occurred_at: 1.hour.ago
      }
    )

    get '/pharma/admin/api/v1/audit_logs',
        params: {
          actor_role: 'viewer',
          status: 403,
          error_code: 'forbidden',
          path_query: 'suppliers',
          occurred_from: 3.hours.ago.iso8601,
          occurred_to: 30.minutes.ago.iso8601,
          limit: 10
        },
        headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to contain_exactly(
      hash_including(
        'id' => matching_log.id,
        'actor_name' => '审计查看客户端',
        'actor_role' => 'viewer',
        'request_method' => 'POST',
        'path' => '/pharma/admin/api/v1/suppliers',
        'status' => 403,
        'error_code' => 'forbidden',
        'request_params' => hash_including('code' => 'SUP-AUDIT-001', 'password' => '[FILTERED]')
      )
    )
    expect(json_body.fetch('meta')).to include('limit' => 10, 'count' => 1)
  end

  it 'shows audit log details' do
    headers, client = admin_client_headers(role: 'operations', name: '运营审计客户端')
    audit_log = audit_log_for(
      client: client,
      status: 201,
      options: { path: '/pharma/admin/api/v1/suppliers' }
    )

    get "/pharma/admin/api/v1/audit_logs/#{audit_log.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch('data')).to include(
      'id' => audit_log.id,
      'admin_api_client_id' => client.id,
      'actor_name' => '运营审计客户端',
      'status' => 201,
      'ip_address' => '127.0.0.1',
      'user_agent' => 'RSpec'
    )
  end

  it 'forbids fulfillment role from reading audit logs and records the denial' do
    headers, _client = admin_client_headers(role: 'fulfillment', name: '履约客户端')

    expect do
      get '/pharma/admin/api/v1/audit_logs', headers: headers
    end.to change(Pharma::AdminAuditLog, :count).by(1)

    expect(response).to have_http_status(:forbidden)
    expect(json_body).to include('error' => 'forbidden')
    expect(Pharma::AdminAuditLog.last).to have_attributes(
      actor_role: 'fulfillment',
      controller_path: 'pharma/admin/api/v1/audit_logs',
      action_name: 'index',
      status: 403,
      error_code: 'forbidden'
    )
  end
end
