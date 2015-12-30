#!/usr/bin/env ruby

=begin
grab the metadata csv and make a json file for traversing all these
different configurations of how a site might position their 
paid content
=end

require 'csv'
require 'json'

META_CSV  = './meta/pilot_sites.csv'
META_JSON = './meta/meta.json'

#helpers up here

def process_field(field)
	if field == nil
		''
	elsif field.start_with?('[')
		field[0] = field[-1] = ''
		field.split(',').map{|i| i.strip()}
	else
		field.strip()
	end
end

def make_json(data)
	data.map { |o| Hash[o.each_pair.to_a] }.to_json
end

=begin
#could just do:
d = CSV.table(META_CSV)
j = d.map{|r| r.to_hash}
=end

data = []

CSV.foreach(META_CSV, headers:true) do |r|
	site = process_field r['site']
	provider = process_field r['farm']
	articles_path = process_field r['articles_selector']
	contents_path = process_field r['contents_selector']
	hl_path = process_field r['content_hl']
	link_path = process_field r['content_link']
	img_path = process_field r['content_img']

	entry = {
		:site => site, 
		:provider => provider, 
		:a_path => articles_path,
		:c_path => contents_path,
		:hl => hl_path,
		:link => link_path,
		:img => img_path
	}

	if entry[:c_path] != ''
		data << entry
	end
end

File.open(META_JSON, 'w') do |f|
	f.puts JSON.pretty_generate(data)
end






