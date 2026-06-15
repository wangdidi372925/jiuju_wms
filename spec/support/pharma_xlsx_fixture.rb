# frozen_string_literal: true

require 'cgi'
require 'tempfile'
require 'zip'

module PharmaXlsxFixture
  def build_xlsx(rows)
    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry('[Content_Types].xml')
      zip.write(content_types_xml)

      zip.put_next_entry('_rels/.rels')
      zip.write(root_relationships_xml)

      zip.put_next_entry('xl/workbook.xml')
      zip.write(workbook_xml)

      zip.put_next_entry('xl/_rels/workbook.xml.rels')
      zip.write(workbook_relationships_xml)

      zip.put_next_entry('xl/worksheets/sheet1.xml')
      zip.write(sheet_xml(rows))
    end

    file = Tempfile.new(['pharma-inventory', '.xlsx'])
    file.binmode
    file.write(buffer.string)
    file.rewind
    file
  end

  private

  def content_types_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
      </Types>
    XML
  end

  def root_relationships_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
      </Relationships>
    XML
  end

  def workbook_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
          <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
        </sheets>
      </workbook>
    XML
  end

  def workbook_relationships_xml
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
      </Relationships>
    XML
  end

  def sheet_xml(rows)
    body = rows.each_with_index.map do |row, row_index|
      row_number = row_index + 1
      cells = row.each_with_index.map do |value, column_index|
        cell_ref = "#{column_name(column_index)}#{row_number}"
        escaped = CGI.escapeHTML(value.to_s)

        %(<c r="#{cell_ref}" t="inlineStr"><is><t>#{escaped}</t></is></c>)
      end.join

      %(<row r="#{row_number}">#{cells}</row>)
    end.join

    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>#{body}</sheetData>
      </worksheet>
    XML
  end

  def column_name(index)
    name = +''
    current = index

    loop do
      name.prepend((65 + (current % 26)).chr)
      current = (current / 26) - 1
      break if current.negative?
    end

    name
  end
end
