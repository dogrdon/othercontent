#!/usr/bin/env ruby

=begin
grab the metadata csv and make a json file for traversing all these
different configurations of how a site might position their 
paid content
=end

require 'csv'
require 'json'

META_FILE = './meta/pilot_sites.csv'

#helpers up here

#TODO deal with the chaining of paths

def process_field(field)
	if field == nil
		''
	elsif field.start_with?('[')
		field[0] = field[-1] = ''
		field.split(',')
	else
		field
	end
end

def make_json(data)
	data.map { |o| Hash[o.each_pair.to_a] }.to_json
end

data = []
#loop through here
CSV.foreach(META_FILE, headers:true) do |r|
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

	data << entry
end

puts make_json(data)