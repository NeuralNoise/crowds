class ItemsController < ApplicationController
  # def index
  #   @items = Item.find(:all)
  # 
  #   respond_to do |format|
  #     format.html # index.html.erb
  #     format.xml  { render :xml => @items }
  #   end
  # end

  # # GET /items
  # # GET /items.xml
  def index
    @crowd = Crowd.find(params[:crowd_id])
    limit  = params[:limit].to_i
    
    #@items = (RAILS_ENV == "production") ? @crowd.popular_items_cached : @crowd.popular_items
    @items = @crowd.recent_items
    @items = @items[0..limit-1] if limit > 0 
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @item }
    end

  rescue ActiveRecord::RecordNotFound
    render :file => "#{RAILS_ROOT}/public/404.html", :status => 404
    #redirect_to :action=>:index
    false
  end
  

  # # GET /items/new
  # # GET /items/new.xml
  # def new
  #   @item = Item.new
  # 
  #   respond_to do |format|
  #     format.html # new.html.erb
  #     format.xml  { render :xml => @item }
  #   end
  # end
  # 
  # # GET /items/1/edit
  # def edit
  #   @item = Item.find(params[:id])
  # end
  # 
  # # POST /items
  # # POST /items.xml
  # def create
  #   @item = Item.new(params[:item])
  # 
  #   respond_to do |format|
  #     if @item.save
  #       flash[:notice] = 'Item was successfully created.'
  #       format.html { redirect_to(@item) }
  #       format.xml  { render :xml => @item, :status => :created, :location => @item }
  #     else
  #       format.html { render :action => "new" }
  #       format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
  #     end
  #   end
  # end
  # 
  # # PUT /items/1
  # # PUT /items/1.xml
  # def update
  #   @item = Item.find(params[:id])
  # 
  #   respond_to do |format|
  #     if @item.update_attributes(params[:item])
  #       flash[:notice] = 'Item was successfully updated.'
  #       format.html { redirect_to(@item) }
  #       format.xml  { head :ok }
  #     else
  #       format.html { render :action => "edit" }
  #       format.xml  { render :xml => @item.errors, :status => :unprocessable_entity }
  #     end
  #   end
  # end
  # 
  # # DELETE /items/1
  # # DELETE /items/1.xml
  # def destroy
  #   @item = Item.find(params[:id])
  #   @item.destroy
  # 
  #   respond_to do |format|
  #     format.html { redirect_to(items_url) }
  #     format.xml  { head :ok }
  #   end
  # end
end
