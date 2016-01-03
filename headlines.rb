#!/usr/bin/env ruby

=begin
getting the headlines that we'll use for inspiration
=end

require 'nokogiri'
require 'capybara/poltergeist'
require 'mongo'
require 'optparse'
require 'json'

BROPTIONS = {:js_errors => false, :timeout => 60}
META_JSON = './meta/meta.json'

site_data = JSON.parse(IO.read(META_JSON))

Capybara.register_driver :poltergeist do |app|
	Capybara::Poltergeist::Driver.new(app, BROPTIONS)
end

def path_format (f)
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
			:path => o[0],
			:sel => o[1]
		}
		return hsh
	elsif f.include?('%') && !f.start_with?('%')
		o = f.split('%')
		hsh = {
			:path => o[0],
			:txt => o[1]
		}
		return hsh
	end
end

def path_order (e)

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

	if mapper['sel']
		doc.css(mapper['path'])[mapper['sel']]
	elsif mapper['txt']
		doc.css(mapper['path']).mapper['txt']
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
		'''
		res.each do |item| #what am i even doing here?
			headline = item[0][:hl]
			link = item[0][:link]
			img = item[0][:img]
			puts "TYPES ARE #{headline}:#{headline.class}, #{link}:#{link.class}, #{img}:#{img.class},"
			content = a_doc.css(item[:path])
			content.each do |c|
			
				#curr_link = get_val(c, link)
				#curr_hl = get_val(c, headline)
				#curr_img = get_val(c, img)

				#puts "WE GOT HERE: #{curr_hl} -- #{curr_img}" 
				puts "just me and the monkey!"

				#if all is correct, save it and move on

			end
		end	
		'''
	end
end