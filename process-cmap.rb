require 'nokogiri'

original_file = ARGV[0]
basename = File.basename(original_file, '.otf')
ttf_file = basename + '.ttf'
original_ttx = basename + "-otf.ttx"
ttf_ttx = basename + "-ttf.ttx"
modified_ttx = basename + "-ttf-modified.ttx"
modified_file = "cmap_modified/" + ttf_file

system "ttx -t cmap -o #{original_ttx} #{original_file} "
system "ttx -t cmap -o #{ttf_ttx} #{ttf_file} "

original_ttx_xml = File.open(original_ttx) { |f| Nokogiri::XML(f) }
cmaps = original_ttx_xml.xpath('//cmap/*').select { |n| n.name.start_with? 'cmap_format' }

print "Processing cmap table...\n"

dup_tables = {}
cmaps.each do
  |cmap|
  key = "#{cmap.name}_#{cmap['platformID']}_#{cmap['platEncID']}"
  rev_table = {}
  dup_table = {}
  cmap.xpath('map').each do
    |map|
    if dup_table[map['name']] 
      dup_table[map['name']] << map['code']
    elsif rev_table[map['name']]
      dup_table[map['name']] = [ rev_table[map['name']], map['code']]
    end
    rev_table[map['name']] = map['code']
  end
  dup_tables[key] = dup_table
end

dup_tables_by_code = {}

dup_tables.each do |k,v|
  code_table = {}
  v.each do |k2,v2|
    v2.each do |code|
      code_table[code] = k2
    end
  end
  dup_tables_by_code[k] = code_table
end


ttf_ttx_xml = File.open(ttf_ttx) { |f| Nokogiri::XML(f, &:noblanks) }
ttf_cmaps = ttf_ttx_xml.xpath('//cmap/*').select { |n| n.name.start_with? 'cmap_format' }

ttf_cmaps.each do
  |cmap|
  key = "#{cmap.name}_#{cmap['platformID']}_#{cmap['platEncID']}"
  dup_results = dup_tables_by_code[key]
  if dup_results && dup_results.size > 0
    cmap.xpath('map').each do
      |map|
      dup_name = dup_results[map['code']]
      if (dup_name && dup_name != map['name'])
        dup_tables[key][dup_name].each do |k,_|
          if dup_results[k]
            dup_results[k] = map['name']
          end
        end
      end
      dup_results.delete(map['code'])
    end
    dup_results.each do |k,v|
      if v != 'cid00001'
        newmap = Nokogiri::XML::Node.new "map", ttf_ttx_xml
        newmap['code'] = k
        newmap['name'] = v
        cmap.add_child newmap
      end
    end
  end
end

File.write(modified_ttx, ttf_ttx_xml.to_xml(indent:3))

system "ttx -m #{ttf_file} -o #{modified_file} #{modified_ttx}"
