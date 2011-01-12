class GridListWidget < Apotomo::Widget
  include GridWidget::Controller
  include AppSupport::Controller
  helper GridWidget::Helper
  helper AppSupport::Helper
    
  # This seemed to get caught up in a cache somewhere, so I moved this into
  # the after_add block.
  # TODO: Try this later
  # responds_to_event :fetchData, :with => :send_json
  # responds_to_event :cellClick, :with => :cell_click
  # responds_to_event :filterSelected, :with => :set_filter
  
  after_add do |me, parent|
    me.respond_to_event :fetchData, :from => me.name, :with => :send_json, :on => me.name
    me.respond_to_event :cellClick, :from => me.name, :with => :cell_click, :on => me.name
    me.respond_to_event :filterSelected, :from => me.name, :with => :set_filter, :on => me.name
    
    parent.respond_to_event :recordUpdated, :from => parent.name, :with => :redisplay, :on => me.name
    
    parent.respond_to_event :recordSelected, :from => me.name, :with => :display_form, :on => parent.name
    parent.respond_to_event :editRecord, :from => me.name, :with => :edit_record, :on => parent.name
    parent.respond_to_event :deleteRecord, :from => me.name, :with => :delete_record, :on => parent.name
    
    @resource = parent.resource
  end
  
  def display
    # Note: no need to load the records because the grid will request them later when it is wired.
    render :locals => {:light_filters => self.set_filter}
  end
  
  # reload the grid in response to :recordUpdated event
  # #grid_reload is defined in jqgrid_support
  def redisplay
    render :text => grid_reload
  end

  # respond to grid's request for data (:fetchData event)
  # #grid_json is defined in jqgrid_support
  def send_json
    render :text => grid_json(load_records).to_json
  end
  
  # respond to a cell click on the grid (:cellClick event)
  # the parameters :col and :id come in with the request
  # TODO: Is that jqGrid-specific enough to put in jqgrid_support?
  def cell_click
    if parent.columns[param(:col).to_i][:inplace_edit]
      trigger :editRecord, :id => param(:id), :col => param(:col)
    else
      trigger :recordSelected, :id => param(:id), :pid => param(:postData) ? param(:postData)[:pid] : nil
    end
  end
  
  # Build the Javascript that will highlight the active filters
  # reponse to a :setFilter event generated by a Javascript event, clicking on a filter
  # #grid_reload and #store_filters are defined in jqgrid_support
  def set_filter
    # In the process, it also collects the string that will be stored 
    # for the grid's data retrieval, and determines whether there are any groups that have
    # no filters selected.
    highlight_active = ''
    filter_parms = []
    groups_active = []
    my_params = parent.get_request_parameters
    if my_params[:filters]
      my_params[:filters].each do |group,filter_ids|
        filter_parm = group
        filter_ids.each do |filter_id|
          highlight_active += <<-JS
          $('#filter_#{parent.dom_id}_#{group}_#{filter_id}').addClass('filter_on').removeClass('filter_off').removeClass('filter_onf');
          JS
          filter_parm += '-' + filter_id.to_s
        end
        filter_parms << filter_parm
        groups_active << group if filter_ids.size > 0
      end
    end
    # Build the Javascript that will turn all the filters in a group to either: neutral if no filters are on,
    # or off, in preparation for turning the active ones on.
    group_style = ''
    parent.filter_sequence.each do |f|
      if groups_active.include?(f)
        group_style += <<-JS
        $('##{parent.dom_id}_list .filter_#{f}').removeClass('filter_on').addClass('filter_off').removeClass('filter_onf');
        JS
      else
        group_style += <<-JS
        $('##{parent.dom_id}_list .filter_#{f}').removeClass('filter_on').removeClass('filter_off').addClass('filter_onf');
        JS
      end
    end
    store_filters = grid_set_post_params(parent.dom_id, {'filters' => filter_parms.join('|')})
    render :text => group_style + highlight_active + store_filters + grid_reload
  end
  
  private 
  
  # #load_records applies all of the filters and constraints and loads the records for display.
  # TODO: This needs to be updated so that it can do pagination and live search
  # TODO: Maybe allow custom sorts depending on the column selected -- to do common subordering.
  # TODO: Consider whether filters should specify ordering, or maybe default ordering
  def load_records
    q = (Object.const_get @resource.classify).scoped

    # sorting
    sort_index = param(:sidx)
    sort_order = (param(:sord) == 'desc') ? 'DESC' : 'ASC'
    if parent.sortable_columns[sort_index]
      column = parent.columns[parent.sortable_columns[sort_index]]      
    else
      if parent.default_sort
        column = parent.columns[parent.sortable_columns[parent.default_sort[0]]]
        sort_order = parent.default_sort[1] ? 'ASC' : 'DESC'
      else
        column = nil
      end
    end
    if column
      if column[:sortable] == true
        if column[:field].include?('.')
          # special handling for associations, try to do the right thing in the simplest/commonest case
          # turns advisor.person.first_name to people.first_name
          # if this doesn't work, you need to use a custom order (set sortable to ['asc string', 'desc string'])
          x = column[:field].split('.').pop(2)
          x[0] = x[0].pluralize
          q = q.order("#{x.join('.')} #{sort_order}")
        else
          q = q.order("#{column[:field]} #{sort_order}")
        end
      else
        # custom override, presuming it is an array
        q = q.order(column[:sortable][sort_order == 'DESC' ? 1 : 0])
      end
    end

    # includes for eager loading
    q = q.includes(parent.includes) if parent.includes
    
    # filtering
    my_params = parent.get_request_parameters
    if my_params[:filters]
    # if filters = get_filter_parameters
      my_params[:filters].each do |group,filter_ids|
        fg_options = parent.filters[group][:options]
        q = q.where(fg_options[:where].call(filter_ids)) if fg_options.has_key?(:where) && filter_ids.size > 0
        q = q.joins(fg_options[:joins]) if fg_options.has_key?(:joins)
        filter_ids.each do |f|
          f_options = parent.filters[group][:filters][f]
          q = q.where(f_options[:where]) if f_options.has_key?(:where)
          q = q.joins(f_options[:joins]) if f_options.has_key?(:joins)
        end
      end
    end
    
    # limits (in case we are, e.g., dependent)
    q = q.where(parent.where.call(my_params[:pid])) if parent.where && my_params[:pid]

    # TODO: Make this work.
    # I should do more error checking here I think.
    # if parent.grid_options[:rows]
    #   # is this expensive?
    #   @total_records = q.count
    #   @page, @shown_rows = [param(:page).to_i, param(:rows).to_i]
    #   @page = 1 if @page < 1
    #   @shown_rows = parent.grid_options[:rows] if @shown_rows < 1
    #   q = q.offset((@page-1)*@shown_rows)
    #   q = q.limit(@shown_rows)
    # end
    
    # get them
    return q.all
    
    # rows_per_page = @rows_per_page
    # if rows_per_page > 0
    #   @total_pages = (@total_records > 0 && rows_per_page > 0) ? 1 + (@total_records/rows_per_page).ceil : 0
    #   @page = @total_pages if @page > @total_pages
    #   @page = 1 if @page < 1
    #   @start_offset = rows_per_page*@page - rows_per_page
    # else
    #   @total_pages = 1
    #   rows_per_page = @total_records
    #   @start_offset = 0
    # end
    # scoped_model.find(:all, :include => find_include, :conditions => find_conditions,
    #   :limit => rows_per_page, :offset => @start_offset, :order => find_order)    
  end
  
end
