#!/usr/bin/env ruby

=begin
getting the headlines that we'll use for inspiration
=end

require 'nokogiri'
require 'capybara/poltergeist'
require 'mongo'
require 'optparse'
require 'json'
require 'cgi'

BROPTIONS = {:js_errors => false, 
	     :timeout => 120,
	     :debug => true, 
	     :phantomjs_options => ['--ignore-ssl-errors=false', '--load-images=false']}
META_JSON = './meta/meta.json'

site_data = JSON.parse(IO.read(META_JSON))

Capybara.register_driver :poltergeist do |app|
	Capybara::Poltergeist::Driver.new(app, BROPTIONS)
end

def revcontent_background_img(i)
	return CGI::parse(i[/\((.*?)\)/m, 1])["\"//img.revcontent.com/?url"][0]

def path_format (f)
	##
	# 
	# 
	
	f = f.strip()
	if f.start_with?("!") || f.start_with?("%")
		v = f[0]
		f[0] = ""
		hsh = {}
		hsh[:path] = ""
		hsh[:sel] = f.strip() if v == '!'
		hsh[:txt] = f.strip() if v == '%'
		return hsh
	elsif f.include?('!') && !f.start_with?('!')
		o = f.split('!')
		hsh = {
			:path => o[0].strip(),
			:sel => o[1].strip()
		}
		return hsh
	elsif f.include?('%') && !f.start_with?('%')
		o = f.split('%')
		hsh = {
			:path => o[0].strip(),
			:txt => o[1].strip()
		}
		return hsh
	end
end

def path_order (e)
	##
	# 
	# 

	c = e['c_path']
	h = e['hl']
	l = e['link']
	i = e['img']
	data = []
	if c.length > 1
		c.each_with_index do |v, ind|

			entry = {
				:path => c[ind],
				:hl => path_format(h[ind]),
				:img => path_format(i[ind]), 
				:link => path_format(l[ind])
			}
			data << entry
		end
		return data
	else
		entry = {
			:path => c[0],
			:hl => path_format(h[0]),
			:img => path_format(i[0]),
			:link => path_format(l[0])
		}
		data << entry
		return data
	end

end

def get_val(doc, mapper)
	#TODO: this is not quite right, need to ensure it's extracting properly
	#ASIDE: Nokogiri has some css parsing issues such as: https://github.com/sparklemotion/nokogiri/issues/581
	if mapper.has_key?(:sel)
		if mapper[:path] == ""
			#v = doc[0][mapper[:sel]]
			v = doc.attributes[mapper[:sel]].value #this may not work across the board
		else
			v = doc.css(mapper[:path])[0][mapper[:sel]]
		end
		if v.include?('background-image') #if this is revcontent, need to extract image url from inline style
			v = revcontent_background_img(v)
		return v
	elsif mapper.has_key?(:txt)
		if mapper[:path] == ""
			#v = doc[0].mapper[:txt]
			v = "i don't even know what to do with this one :)" #should log this instead.
		else
			v = doc.css(mapper[:path])[0].mapper[:txt]
		end
		return v
	end
end

def ensure_domain(f, domain, articles)
	f.puts "DOMAIN: #{domain}, ARTICLES: #{articles}"
	articles.map do |a|
		if a.start_with?('/')
			domain << a
		else
			a
		end
	end
end

f1 = File.open('./logging.txt', 'w')

site_data.each do |e|
	session = Capybara::Session.new(:poltergeist)
	#TODO - outsource all this repetition to a function and return all the things - that's OOP?
	start = e['site']
	article_path = e['a_path']
	res = path_order e #reach into each meta entry and sort out the arrayed paths
	
	session.visit start
	
	doc = Nokogiri::HTML(session.html)
	articles = doc.css(article_path).map{ |l| l['href'] }[0..1] # this range can be inc, or low, for desired effect
	articles = ensure_domain(f1, start, articles)
	articles.each do |a|
		puts "WRITING ADDRESS"
		f1.puts "grabbing #{a}"
		session.visit a
		a_doc = Nokogiri::HTML(session.html)
		puts "WRITING RESULTS"
		f1.puts "THIS IS THE RESULTS: #{res.class} == #{res}"
		res.each do |item|
			cpath = item[:path]
			headline = item[:hl]
			link = item[:link]
			img = item[:img]
			content = a_doc.css(cpath)
			content.each do |c|
				curr_link = get_val(c, link)
				curr_hl = get_val(c, headline)
				curr_img = get_val(c, img)

				File.open('../data/results.csv', 'a') { |f|
					f.puts "\"#{curr_hl}\", #{curr_img}, #{curr_link}\n"
				}

				#TODO - when all is correct, eventually, save it and move on

			end
		end	
		
	end
end
