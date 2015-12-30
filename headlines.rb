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

site_data.each do |e|
	session = Capybara::Session.new(:poltergeist)
	start = e['site']
	article_path = e['a_path']
	content_path = e['c_path']
	#this is where we need to check with what grabs what we need
	hl = e['hl']
	link = e['link']
	img = e['img']
	session.visit start
	doc = Nokogiri::HTML(session.html)
	articles = doc.css(article_path).map{ |l| l['href'] }[0..5]
	articles.each do |a|
		puts "grabbing #{a}"
		session.visit a
		a_doc = Nokogiri::HTML(session.html)
		content = a_doc.css(content_path)
		#content.foreach do |c|
			#this is not right but it's pseudo right for now
		#	h = c.css(hl)
		#	l = c.css(link)
		#	i = c.css(img)
		puts content
	end
end