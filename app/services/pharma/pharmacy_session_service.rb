# frozen_string_literal: true

module Pharma
  class PharmacySessionService
    Result = Struct.new(:pharmacy_user, :token_record, :raw_token, keyword_init: true)

    class SessionError < StandardError
      attr_reader :code, :status

      def initialize(code, message, status: :unauthorized)
        @code = code
        @status = status
        super(message)
      end
    end

    def create(email:, password:, pharmacy_code: nil)
      user = authenticate_user(email: email, password: password)
      pharmacy_user = pharmacy_user_for(user: user, pharmacy_code: pharmacy_code)
      raise SessionError.new('pharmacy_not_allowed', '药店当前不允许采购', status: :unprocessable_entity) unless pharmacy_user.can_purchase?

      token_record, raw_token = Pharma::PharmacyApiToken.issue!(pharmacy_user: pharmacy_user)
      Result.new(pharmacy_user: pharmacy_user, token_record: token_record, raw_token: raw_token)
    end

    private

    def authenticate_user(email:, password:)
      user = Spree::User.find_by('LOWER(email) = ?', email.to_s.strip.downcase)
      return user if user&.valid_password?(password.to_s)

      raise SessionError.new('invalid_credentials', '账号或密码错误')
    end

    def pharmacy_user_for(user:, pharmacy_code:)
      scope = Pharma::PharmacyUser.active.includes(:pharmacy).where(spree_user_id: user.id)
      scope = scope.joins(:pharmacy).where(pharma_pharmacies: { code: pharmacy_code }) if pharmacy_code.present?

      pharmacy_users = scope.to_a
      return pharmacy_users.first if pharmacy_users.one?

      raise SessionError.new('pharmacy_not_bound', '账号未绑定该药店', status: :unprocessable_entity) if pharmacy_users.empty?

      raise SessionError.new('pharmacy_required', '请选择要登录的药店', status: :unprocessable_entity)
    end
  end
end
