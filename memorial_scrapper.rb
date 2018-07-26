require 'rubygems'
require 'csv'
require 'open-uri'
require 'json'
require 'date'
require 'mechanize'
require 'sanitize'
require 'webshot'

class MemorialScraper

	attr_accessor :read_file, :write_file

	def initialize(read_file, write_file)
		@read_file = ARGV.first
		@write_file = ARGV[1]
		initiate_mechanize
	end	

	def initiate_mechanize
		@mechanize = Mechanize.new
	end	

	def check_directory_exists(directory)
		if !Dir.exists?(directory)
			Dir.mkdir(directory, 0755)
			puts "Made dir: #{directory}"
		end
	end

	def download_object(name, object)
		File.open(name,'wb') do |fo|
			fo.write open(object,{ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE}).read
		end
	end

	def social_media_screencapture(link, id)
		@ws.capture link, "#{@directory}/#{id}_screencapture.png", width: 800, height: 800, timeout: 60
	end	

	def call_mechanize(link)
		begin
			@mechanize.get(link)
		rescue Exception => e
  			page = e
		end	
	end	

	def make_cvs
		CSV.open(@write_file, 'ab') do |csv|
			new_file = CSV.read(@write_file,:encoding => "iso-8859-1",:col_sep => ",")
		  	if new_file.none?
		    	csv << ["public", "featured", "type", "collection", "longitude", "latitude", "name", "comment", "inscription", "page_url", "erected_by", "erected_date", "categories", "credits", "images", "image_names", "image_captions", "image_credits"]
		  	end
			CSV.foreach(@read_file, headers:true) do |record|
				page = call_mechanize(record['link1_href'])
				get_images(page, ARGV[2])
				csv << ["true", "true", "Official (Historical Marker Database)", ARGV.last, record['X'], record['Y'], record['name'], record['cmt'], Sanitize.fragment(record['desc']), record['link1_href'], get_builtby(page), get_builtyear(page), get_categories(page), get_credits(page), @img_files.join(", "), @img_names.join(", "), @img_captions.join(", "), @img_credits.join(", ")]
			end	
		end			
	end	

	def get_credits(page)
		split_text = page.at('article').text.split("Credits. ")
		full_credits = split_text[1]
		split_credits = full_credits.split(" Photos:")
		credits = split_credits[0]
		return credits
	end	

	def get_builtyear(page)
		get_buildinginfo(page)
		return @build_info.first
	end

	def get_builtby(page)
		get_buildinginfo(page)
		return @build_info.last
	end

	def get_buildinginfo(page)
		text = page.at('article').text
		if text.include?("Marker series.")
			if text.include?("Erected by")
				split_text = text.split"Erected by"
				newtext = split_text[1]
				full_buildinginfo = newtext.split("Marker series.")
				buildinginfo = full_buildinginfo[0]
				erected_by = buildinginfo.gsub(/\W+$/, "").strip
				erected_date = nil
			elsif text.include?("Erected ")
				split_text = text.split"Erected "
				newtext = split_text[1]
				full_buildinginfo = newtext.split("Marker series.")
				buildinginfo = full_buildinginfo[0]	
				bi_array = buildinginfo.split("by")
				erected_date = bi_array[0].strip
				if bi_array[1].nil?
					erected_by = nil
				else	
					erected_by = bi_array[1].gsub(/\s\W/, "").strip
				end		
			else
				erected_date = nil
				erected_by = nil	
			end	
		else
			if text.include?("Erected by")
				split_text = text.split"Erected by"
				newtext = split_text[1]
				full_buildinginfo = newtext.split("Location. ")
				buildinginfo = full_buildinginfo[0]
				erected_by = buildinginfo.gsub(/\W+$/, "").strip
				erected_date = nil
			elsif text.include?("Erected ")
				split_text = text.split"Erected "
				newtext = split_text[1]
				full_buildinginfo = newtext.split("Location. ")
				buildinginfo = full_buildinginfo[0]	
				bi_array = buildinginfo.split("by")
				erected_date = bi_array[0].strip
				if bi_array[1].nil?
					erected_by = nil
				else	
					erected_by = bi_array[1].gsub(/\s\W/, "").strip
				end	
			else
				erected_date = nil
				erected_by = nil		
			end	
		end		
		@build_info = [erected_date, erected_by]
		return @build_info
	end	

	def get_categories(page)
		split_text = page.at('article').text.split("Categories. ")
		full_categories = split_text[1]
		if full_categories.include?("•\r")
			split_categories = full_categories.split("•\r")
		else
			split_categories = full_categories.split(/•\W+Credits./)
		end		
		clean_categories = split_categories[0].gsub(/^\W+/, "").strip
		categories = clean_categories.split(" • ")* ","
		return categories
	end

	def get_images(page, storage_directory)
		@img_files = []
		@img_names = []
		@img_captions = []
		@img_credits = []
		check_directory_exists(storage_directory)
		directory = storage_directory
		images = page.images
		if !images.empty?
			images. each do |image|
				if image.uri.to_s.include?("/Photos")
					image_source = image.uri.to_s
					image_name = directory + "/" + image.uri.to_s.split("/").last
					@img_files << image_source
					@img_names << image_name
					download_object(image_name, image_source)
				end
			end
		end			
		images_info = []
		page.search('div.photoright').each do |ir|
			images_info << ir
		end	
		page.search('div.photoleft').each do |il|
			images_info << il
		end	
		page.search('div.photoafter').each do |ia|
			images_info << ia
		end	
		page.search('div.photofull').each do |ipf|
			images_info << ipf
		end	
		if !images_info.empty?
			images_info.each do |info|
				if !info.children.children.children[2].nil?
					image_caption = info.children.children.children[2].text
				else
					image_caption = nil	
				end	
				if !info.children.children.children[1].nil?
					image_credit = info.children.children.children[1].text
				else
					image_credit = nil
				end	
				@img_captions << image_caption
				@img_credits << image_credit
			end	
		end
	end	
	
end		

file = MemorialScraper.new(ARGV.first, ARGV[1])
file.make_cvs	