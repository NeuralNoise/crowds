#!/usr/bin/env ruby
RAILS_ENV = (ARGV[1].nil? ? 'development' : ARGV[1])

require 'rubygems'
require 'typhoeus'
require 'json'

ROOT = File.expand_path(File.dirname(__FILE__)+'/../../')
require "#{ROOT}/config/environment.rb"
require "#{ROOT}/config/crowds.rb"

MAX_CON = 20

# quiet
ActiveRecord::Base.logger = Logger.new(STDOUT) # direct all log to output, which is then directed to the daemon's log file

cycle_start = Time.now
puts "#{cycle_start} [Normalizr] Initialized in #{RAILS_ENV}"

# Get to work


hydra = Typhoeus::Hydra.new(:max_concurrency => MAX_CON)
hydra.disable_memoization

ctr = 0
fail_count = 0

loop do
    
    # order by id, mark all as normalized allow the next normalizr process to pick new ones
    items = Item.all(:conditions => "normalized = 0", :order => "id", :limit => MAX_CON)
    
    if items.size == 0 # never quit...
        puts "#{Time.now} [Normalizr] Done. Took #{(Time.now - cycle_start).round} seconds to clean #{ctr} items."# Sleep(60) and go again!"
        
        ## single loop
        # cycle_start = Time.now ; ctr = 0
        # sleep(300) 
        # next
        
        exit!
    end

    Item.update_all "normalized = 1", "id BETWEEN #{items.first.id} AND #{items.last.id}"
    
    ctr += items.size
    
    items.each do |i|     
    
        req = Typhoeus::Request.new("http://therealurl.appspot.com/",
                                    :params => { "format" => "json", "url" => i.url },
                                    :timeout => 20000 )

        req.on_complete do |resp|
            # TheRealURL down or not responding (404 is acceptable, simply means that TheRealURL couldn't access the URL supplied)
            if resp.code != 200 and resp.code != 404
                fail_count += 1
                puts "ERROR from TheRealURL: #{resp.code} on '#{i.url}'"
                if fail_count < 10 
                    puts "Sleep(60), next"
                    sleep(60)
                    next
                else
                    puts "10 ERRORS. EXITING"
                    Item.update_all "normalized = 0", "id BETWEEN #{items.first.id} AND #{items.last.id}"
                    exit
                end
            end
            
            fail_count = 0
            
            # request successful
            if resp.code == 200
                begin
                    d = JSON.parse(resp.body)
                    if i.url != d['url'] and d['url'] != 'http://twitter.com/login' and d['url'] != 'http://digg.com/register/'
                        i.update_attributes :url => d['url'], :title => d['title']
                    elsif d['title'] != i.title.to_s
                        i.update_attribute "title", d['title']
                    end
                rescue Exception => e
                    puts "ERROR: #{e} [#{i.url}]"
                end
            end
            
        end
        hydra.queue req
    end 
    hydra.run
    sleep(1)
end