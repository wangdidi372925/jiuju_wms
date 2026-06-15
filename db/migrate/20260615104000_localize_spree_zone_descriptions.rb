# frozen_string_literal: true

class LocalizeSpreeZoneDescriptions < ActiveRecord::Migration[8.1]
  DESCRIPTION_UPDATES = {
    'USA + Canada' => '美国和加拿大',
    'Central America and Caribbean' => '中美洲和加勒比',
    'South America' => '南美',
    'Middle East' => '中东',
    'Africa' => '非洲',
    'Asia' => '亚洲',
    'Australia and Oceania' => '澳大利亚和大洋洲'
  }.freeze

  def up
    update_descriptions(DESCRIPTION_UPDATES)
  end

  def down
    update_descriptions(DESCRIPTION_UPDATES.invert)
  end

  private

  def update_descriptions(values)
    return unless table_exists?(:spree_zones) && column_exists?(:spree_zones, :description)

    values.each do |from, to|
      execute <<~SQL.squish
        UPDATE #{quote_table_name(:spree_zones)}
        SET description = #{quote(to)}
        #{updated_at_clause}
        WHERE description = #{quote(from)}
      SQL
    end
  end

  def updated_at_clause
    return '' unless column_exists?(:spree_zones, :updated_at)

    ", updated_at = #{quote(Time.current)}"
  end
end
