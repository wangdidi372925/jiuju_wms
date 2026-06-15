# frozen_string_literal: true

require 'rexml/document'
require 'zip'

module Pharma
  class XlsxReader
    class ParseError < StandardError; end

    SHEET_ENTRY = 'xl/worksheets/sheet1.xml'
    SHARED_STRINGS_ENTRY = 'xl/sharedStrings.xml'

    def initialize(file)
      @file = file
    end

    def rows
      Zip::File.open(file_path) do |zip|
        sheet_entry = zip.find_entry(SHEET_ENTRY)
        raise ParseError, 'worksheet sheet1.xml not found' if sheet_entry.blank?

        parse_sheet(sheet_entry.get_input_stream.read, shared_strings(zip))
      end
    rescue Zip::Error, REXML::ParseException => e
      raise ParseError, e.message
    end

    private

    attr_reader :file

    def file_path
      file.respond_to?(:path) ? file.path : file.to_s
    end

    def shared_strings(zip)
      entry = zip.find_entry(SHARED_STRINGS_ENTRY)
      return [] if entry.blank?

      document = REXML::Document.new(entry.get_input_stream.read)
      string_items = []
      REXML::XPath.each(document, "//*[local-name()='si']") do |item|
        text = +''
        REXML::XPath.each(item, ".//*[local-name()='t']") { |node| text << node.text.to_s }
        string_items << text
      end
      string_items
    end

    def parse_sheet(xml, shared_strings)
      document = REXML::Document.new(xml)
      parsed_rows = []

      REXML::XPath.each(document, "//*[local-name()='row']") do |row|
        parsed_rows << parse_row(row, shared_strings)
      end

      parsed_rows
    end

    def parse_row(row, shared_strings)
      cells = []

      REXML::XPath.each(row, "*[local-name()='c']") do |cell|
        index = column_index(cell.attributes['r'].to_s)
        cells[index] = cell_value(cell, shared_strings)
      end

      cells.map { |value| value.to_s.strip }
    end

    def cell_value(cell, shared_strings)
      case cell.attributes['t']
      when 'inlineStr'
        inline_text(cell)
      when 's'
        shared_strings[value_text(cell).to_i].to_s
      else
        value_text(cell)
      end
    end

    def inline_text(cell)
      text = +''
      REXML::XPath.each(cell, ".//*[local-name()='t']") { |node| text << node.text.to_s }
      text
    end

    def value_text(cell)
      REXML::XPath.first(cell, "*[local-name()='v']")&.text.to_s
    end

    def column_index(cell_reference)
      letters = cell_reference[/[A-Z]+/].to_s
      letters.chars.reduce(0) { |sum, char| (sum * 26) + char.ord - 64 } - 1
    end
  end
end
