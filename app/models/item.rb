class Item < ActiveRecord::Base

  belongs_to :feed
  
  validates_uniqueness_of :url, :scope => :feed_id
  
  before_validation :normalize_it
  
  
  def normalize_it
    u = open(self.url)
    self.url = u.base_uri.to_s  # get real, unshortened, URL
    self.title = extract_title(u.read) if self.title.nil? # get title - unless the URL is a feed post URL in which we already have it
  end


  def extract_title(html)
    html.scan(/<title.*?>(.*?)<\/title>/mi).first.to_s.strip
  rescue Exception=>e
    ''
  end
  
  
  # Housekeeping: removes old items from the DB
  def self.delete_old
    self.delete_all "created_at < '#{(Gaps.max+10).days.ago.to_s(:db)}'"
  end

end