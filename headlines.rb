#!/usr/bin/env ruby

=begin
getting the headlines that we'll use for inspiration
=end

require 'nokogiri'
require 'capybara/poltergeist'
require 'mongo'
require 'optparse'

BROPTIONS = {:js_errors => false}
TEST_BASE = 'http://www.nydailynews.com'


Capybara.register_driver :poltergeist do |app|
	Capybara::Poltergeist::Driver.new(app, BROPTIONS)
end

session = Capybara::Session.new(:poltergeist)

session.visit TEST_BASE

doc = Nokogiri::HTML(session.html)

links = doc.css('div.teaser p a').map{ |l| l['href'] }[0..5]

puts links