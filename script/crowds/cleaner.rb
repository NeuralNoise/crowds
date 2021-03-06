#!/usr/bin/env ruby
require 'rubygems'
require 'typhoeus'
require 'json'

RAILS_ENV = (ARGV[1].nil? ? 'development' : ARGV[1])
ROOT = File.expand_path(File.dirname(__FILE__)+'/../../')
require "#{ROOT}/config/environment.rb"
require "#{ROOT}/config/crowds.rb"

# quiet
ActiveRecord::Base.logger = Logger.new(STDOUT) # direct all log to output, which is then directed to the daemon's log file

cycle_start = Time.now
puts "#{Time.now} [Cleaner] Initialized in #{RAILS_ENV}"

c = Crowd.delete_all "delete_at <= '#{Time.now.to_s(:db)}'"

puts "[Cleaner] deleted #{c} crowds scheduled for removal"


# clean up items table
c = Item.delete_all "created_at > '#{TimeframeEnd.days.from_now.to_s(:db)}'"  # some items have a future date..
puts "[Cleaner] deleted #{c} items from the future"

c = Item.delete_all "created_at < '#{TimeframeStart.days.ago.to_s(:db)}'"     # remove old items
puts "[Cleaner] deleted #{c} old items"

deadfeeds = Feed.all(:conditions => "fail_count > 10000")

deadfeeds.each do |f|
  f.ownerships.destroy_all
  f.destroy
end

puts "[Cleaner] deleted #{deadfeeds.size} dead feeds"


puts "#{Time.now} [Cleaner] Done. Take care!"
