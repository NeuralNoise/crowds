# require 'feed_tools'
require 'feedzirra'
require 'mytrufflehog'

class Crowd < ActiveRecord::Base

  has_many :ownerships, :dependent => :destroy
  has_many :feeds, :through => :ownerships, :order=>"feeds.created_at DESC" #, :include => :items

  belongs_to :user
  
  validates_length_of :title, :in => 3..99, :too_short => "Title too short", :too_long => "Title too long"
  validates_uniqueness_of :title


  def add_feed_from_url(url, refresh = false)
    # discover RSS/Atom URL, if needed
    url = MyTruffleHog.parse_from(url).to_a.first

    return false if url.nil?
    
    f = Feedzirra::Feed.fetch_and_parse(url)
    
    return false if f.title.nil? #title is required for both RSS/Atom, so it tells us if FeedTools actually found a feed

    feed = self.add_feed({:url => (f.feed_url.nil?) ? feed_url : f.feed_url, :home_url => f.url, :title => f.title})
    feed.refresh(f) if refresh
    
    feed
  rescue Exception => e
    logger.error "ERROR Crowd::add_feed_from_url(#{url}, #{refresh})"
  end

  # def add_feed_from_url(url)
  #   rss = FeedTools::Feed.open(url)
  #   return false if rss.title.nil? #title is required for both RSS/Atom, so it tells us if FeedTools actually found a feed
  # 
  #   # rss.url.nil? is for feeds that don't carry their own URL, eg news.YC
  #   self.add_feed({:url => (rss.url.nil?) ? feed_url : rss.url, :home_url => rss.link, :title => rss.title})
  # rescue FeedTools::FeedAccessError
  #   false
  # end
  
  
  # data is a hash {:url => feed_url, :home_url => rss.link, :title => rss.title}
  def add_feed(data)
    data[:home_url] ||= data[:url]
    
    feed = Feed.find_by_url(data[:url]) 
    
    if feed.nil? 
      feed = Feed.create(data)
    else
      feed.update_attributes(:home_url=>data[:home_url], :title=>data[:title])
    end
    
    Ownership.find_or_create_by_feed_id_and_crowd_id(feed.id, self.id)
    feed #for display use
  end
  
  
  # deprecated
  # def refresh_feeds
  #   self.feeds.each do |f|
  #     if f.refresh
  #       logger.info "Refreshed #{f.url}"
  #     else
  #       logger.error "Failed refresh #{f.url}"
  #     end
  #   end
  # end


  def popular_items_since(since, threshold = DefaultThreshold, limit = DefaultItemLimit)
    
    logger.info "Reading popular_items_since #{since}"
    
    items = {} ; items.default = {} ; filt = [] ; item_counter = {}
    since_db = since.to_s(:db)
    now = Time.now.to_i
#    cur_time = ((Time.now - since)/86400).round

    (Item.find_by_sql "SELECT url FROM items WHERE created_at >= '#{since_db}' GROUP BY url HAVING count(*)>=#{threshold}").each do |i|
       filt << i.url
     end

    return [] if filt.size == 0 # no new URLs

    sql = "SELECT items.url as url, items.id as id, items.title as title, items.feed_id as feed_id, items.source_id as source_id,
                   DATE(items.created_at) as created_day
          FROM items, ownerships
          WHERE 
            items.feed_id = ownerships.feed_id
            AND ownerships.crowd_id=#{self.id}
            AND items.created_at > '#{since_db}'
          ORDER BY 
            items.created_at DESC
          LIMIT 5000"

    (Item.find_by_sql sql).each do |res|
      url = res.url
#      next unless filt.include?(url)

      res.source_id ||= res.id
      source = Item.find(res.source_id)

      f = items[url].has_key?(:feeds) ? items[url][:feeds] << source : [source]
      items[url] = { :title => res.title, :feeds => f, :period => res.created_day } #((now - res.created_day.to_i)/86400).round } #:period => cur_time }

      item_counter[url] = true if items[url][:feeds].size >= threshold
     # break if item_counter.size >= limit # save time
    end

    items.delete_if {|url, data| data[:feeds].length < threshold }
    logger.info "Items.size: #{items.size}"
    items.each_key { |url| items[url][:tags] = Tag.get_for(url) }
    items.sort_by { |a| [a[1][:period], a[1][:feeds].size] }.reverse
  end


  def recent_items(threshold = DefaultThreshold, limit = DefaultItemLimit)
    Item.class # required for Marshal.load -> see http://tinyurl.com/c6scxw
    
    cachefile = CacheDir + "/Item.popular.crowd-#{id}.thres-#{threshold}.limit-#{limit}.cache"
    cache_fresh = false
    
    if File.exist?(cachefile)
      last_updated = File.mtime(cachefile).utc
      cache_fresh = (last_updated > CacheLifetime.hours.ago)

      items = Marshal.load(File.read(cachefile))
      items = popular_items_since(last_updated, threshold, limit) + items unless cache_fresh

    else
      logger.info "calling popular_items_since(#{1.month.ago}, #{threshold}, #{limit})"
      items = popular_items_since(1.month.ago, threshold, limit)
    end
      
    items = items[0..(limit-1)]   # remove older items
    
    File.open(cachefile, 'w') {|f| f.puts Marshal.dump(items); f.close} unless cache_fresh or items.size < 1
    
    logger.info "FOUND #{items.size} items"
    items
  end
  
  ## Deprecated - moved to crowds/cleaner script
  # # Housekeeping: remove crowds marked for deletion over a week ago (allow for delete undo, up to a week)
  # 
  # def self.remove_deleted
  #   self.delete_all "delete_at <= '#{Time.now.to_s(:db)}'"
  # end
  
end