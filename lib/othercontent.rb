#!/usr/bin/env ruby

=begin
main script for scraping websites using their paths to suggested content as 
provided in `$APP_HOME/meta/meta.json`. Right now metashaper.rb has to be run
manually on `$APP_HOME/meta/pilot_sites.csv` whenever that resource changes
=end

require_relative 'othercontent/store'
require ENV["HOME"]+'/othercontent/etc/conf/mongo_conf'

require 'nokogiri'
require 'capybara/poltergeist'
require 'mongo'
require 'json'
require 'cgi'
require 'net/http'
require 'phantomjs'

##
# CONFIGURATION AND SET UP
##

if ARGV[0] == "test"
	TEST = true
else
	TEST = false
end


BROPTIONS = {:phantomjs => Phantomjs.path, :js_errors => false, :timeout => 120, :phantomjs_options => ['--ignore-ssl-errors=false', '--load-images=false']}
USER_AGENT = "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:40.0) Gecko/20100101 Firefox/40.1"
META_PATH = ENV["HOME"]+'/othercontent/meta/'

if TEST
	META_JSON = META_PATH + 'meta_test.json'
	BROPTIONS[:debug]=true
else
	META_JSON = META_PATH + 'meta.json'
end


site_data = JSON.parse(IO.read(META_JSON))

begin
	if TEST
		puts "Not opening storage because this is only a test"
	else
		storage = Store::MongoStore.new(MONGO_CONF[:host], MONGO_CONF[:port], MONGO_CONF[:database], MONGO_CONF[:collection])
	end
rescue => error
	puts "OTHERCONTENT-ERROR: Something wrong happened when connecting to db store: #{error}"
end

Capybara.register_driver :poltergeist do |app|
	Capybara::Poltergeist::Driver.new(app, BROPTIONS)
end

##
# /CONFIGURATION AND SET UP
##


##
# HELPER FUNCTIONS
##

def revcontent_background_img(i)
	return CGI::parse(i[/\((.*?)\)/m, 1])["http://img.revcontent.com/?url"][0]
end

def path_format (f)
	##
	# this function helps us determine where we get the path from the html
	# ! and % are used as special characters to indicate whether this part of the
	# path comes from the attribute of the element that follows, 
	# or the text of the element that follows, respectively
	
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
	# this function is used if there are more than one provider,
	# and which provider it is, for that set of context
	# see $APP_HOME/meta/pilot_sites.csv for which 
	# sites have multiples.

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
	##
	# This will retrieve the value for a path in HTML based on whether it's
	# an attribute (:sel) or element text (:txt)

	if mapper.has_key?(:sel)
		begin	
			if mapper[:path] == ""
				v = doc.attributes[mapper[:sel]].value #this may not work across the board
			else
				v = doc.css(mapper[:path])[0][mapper[:sel]]
			end
			if v.include?('background-image') #if this is revcontent, need to extract image url from inline style
				v = revcontent_background_img(v)
			end
			return v
		rescue => error
			puts "OTHERCONTENT-WARNING: sel path did not return anything: #{error}"
			return nil
		end
	elsif mapper.has_key?(:txt)
		begin
			if mapper[:path] == ""
				v = doc[0].mapper[:txt]
			else
				v = doc.css(mapper[:path])[0].mapper[:txt]
			end
			return v
		rescue => error
			puts "OTHERCONTENT-WARNING: txt path did not return anything: #{error}"
			return nil
		end
	end
end

def ensure_domain(domain, articles)
	##
	# Some sites use relative links and so you don't get a full url scraping them
	# This just makes sure that the relative links are expanded to full urls

	articles.map do |a|
		unless a.include?(domain)
			URI.join(domain, a).to_s
		else
			a
		end
	end
end

def get_target(url)
	##
	# Here we want to get the ultimate target for a link
	# because there might be a lot of redirects
	# might be a better way to do this with headers and not load the whole resource,
	# but we won't suffer now for this
	begin
		res = Net::HTTP.get_response(URI(url))
		return res['location']
	rescue => error
		puts "ERROR: target resolution did not work for #{url}: #{error}"
		return "NA"
	end
end

##
# /HELPER FUNCTIONS
##

##
# MAIN PROCEDURE
##

site_data.each do |e|
	session = Capybara::Session.new(:poltergeist)
	session.driver.headers = {"User-Agent" => USER_AGENT}
	start = e['site']
	article_path = e['a_path']
	res = path_order e #reach into each meta entry and sort out the arrayed paths
	
	session.visit start
	
	doc = Nokogiri::HTML(session.html)
	articles = ensure_domain(start, doc.css(article_path).map{ |l| l['href'] }[0..1]) # this range can be inc, or low, for desired effect
	articles.each do |a|
		session.visit a
		a_doc = Nokogiri::HTML(session.html)
		res.each do |item|
			if TEST
				puts "Fetching: #{a}"
			end
			cpath = item[:path]
			headline = item[:hl]
			link = item[:link]
			img = item[:img]
			content = a_doc.css(cpath)
			if TEST
				puts "GETTING: #{cpath}"
			end
			content.each do |c|
				if TEST
					puts "getting content for: #{c}"
				end
				curr_location = a
				curr_link = get_val(c, link)
				curr_hl = get_val(c, headline)
				curr_img = get_val(c, img)
				access_time = Time.now
				if curr_link.start_with?('//') 
					curr_link.prepend('http:')
				end
				curr_target = get_target(curr_link)

				cdoc = {content_link:curr_link, content_text:curr_hl, content_img_src:curr_img, content_location:curr_location, content_target:curr_target, accessed_at:access_time}
				
				#save it
				begin
					#TODO: eventually don't save repeats, but right now we want to see everything
					#TODO: eventually save frequency of saved items (if repeats?) - maybe put this downstream
					if TEST
						puts "Returning: #{cdoc}"
					else
						if !storage.checkrecord('content_link', cdoc[:content_link])
							storage.insertdoc(cdoc)
						end
					end
				rescue => error
					puts "OTHERCONTENT-ERROR: Something wrong happened when storing in db store: #{error}"
				end
			end
		end			
	end
    session.driver.quit
end

