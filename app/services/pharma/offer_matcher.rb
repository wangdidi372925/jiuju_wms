# frozen_string_literal: true

module Pharma
  class OfferMatcher
    DEFAULT_MIN_EXPIRY_DAYS = 180

    def call(drug_master:, pharmacy:, quantity:, province:, city: nil,
             min_expiry_date: DEFAULT_MIN_EXPIRY_DAYS.days.from_now.to_date)
      return [] unless pharmacy.purchasing_enabled?

      SupplierOffer
        .includes(:supplier, :supplier_warehouse, :supplier_offer_regions, :drug_batch_stocks)
        .where(drug_master: drug_master, status: 'approved')
        .select do |offer|
          offer.available_for?(
            province: province,
            city: city,
            quantity: quantity,
            min_expiry_date: min_expiry_date
          )
        end
        .sort_by { |offer| ranking_key(offer, province: province, city: city, min_expiry_date: min_expiry_date) }
    end

    private

    def ranking_key(offer, province:, city:, min_expiry_date:)
      [
        offer.unit_price,
        -offer.supplier.priority,
        delivery_days_for(offer, province: province, city: city),
        -offer.best_available_stock(min_expiry_date: min_expiry_date).expiry_date.to_time.to_i
      ]
    end

    def delivery_days_for(offer, province:, city:)
      offer.supplier_offer_regions
           .select { |region| region.available_for?(province: province, city: city) }
           .map(&:delivery_days)
           .min || 99
    end
  end
end
