# frozen_string_literal: true

Rails.application.config.to_prepare do
  next unless defined?(Spree::Admin::BaseHelper)

  Spree::Admin::BaseHelper.module_eval do
    def spree_time(time, options = {})
      return '' if time.blank?

      localized_title = time.in_time_zone.strftime('%Y-%m-%d %H:%M')
      local_time(time, { format: '%Y-%m-%d %H:%M', title: localized_title }.merge(options))
    end

    def spree_time_ago(time, options = {})
      return '' if time.blank?

      spree_time(time, options)
    end
  end
end
