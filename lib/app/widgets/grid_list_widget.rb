class GridListWidget < Apotomo::Widget
  include GridWidget::ControllerMethods
  include GridWidget::CustomDisplayMethods
  include GridWidget::AppSupport::ControllerMethods
  helper GridWidget::HelperMethods
  helper GridWidget::AppSupport::HelperMethods

  attr_reader :total_pages
  attr_reader :total_records
  attr_reader :current_page
    
  after_add do |me, mom|
    me.respond_to_event :fetch_data, :from => me.name
    me.respond_to_event :cell_click, :from => me.name
    me.respond_to_event :add_button, :from => me.name
    
    mom.respond_to_event :reload_grid, :from => mom.name, :on => me.name
    
    mom.respond_to_event :display_form, :from => me.name
    mom.respond_to_event :inplace_edit, :from => me.name
    mom.respond_to_event :delete_record, :from => me.name
  end
  
  # display and wire the list grid and filters.
  # Records are loaded later, after grid is wired.
  # Grid wiring is handled by grid_place defined in jqgrid_support.
  def display
    render
  end
  
  # respond to grid's request for data (:fetch_data event)
  # filtering parameters and parent id (if any) should come in as event parameters, used by load_records
  # relies on #grid_json to format the output properly, which is defined in jqgrid_support
  # TODO: Can I make these a bit more chainable?
  # Magic: use_pagination sets some instance variables that grid_json uses.
  def fetch_data(evt)
    query = use_sort(resource.scoped, evt)
    query = use_filter(query, evt)
    query = query.includes(includes) if includes    
    query = query.where(where.call(evt[:pid])) if where && evt[:pid]
    render :text => grid_json(use_pagination(query, evt)).to_json
  end
  
  # reload the grid in response to :reload_grid event
  # relies on #grid_reload, which is defined in jqgrid_support
  def reload_grid
    render :text => grid_reload
  end

  # respond to a cell click on the grid (:cell_click event)
  # relies on #grid_event_spec, which is defined in jqgrid_support
  def cell_click(evt)
    click_spec = grid_event_spec(evt)
    if columns[click_spec[:col]][:inplace_edit]
      trigger :inplace_edit, :id => click_spec[:id], :col => click_spec[:col]
    elsif columns[click_spec[:col]][:open_panel]
      trigger :display_form, :id => click_spec[:id]
    # else this is just a select
    end
  end
  
  # respond to the add button on the grid (:add_button event)
  def add_button(evt)
    trigger :display_form, :id => nil, :pid => evt[:pid]
  end
    
  # parse and update the filters based on the passed paramters
  def parse_filters(evt)
    return_filters = {}
    passed_filters = []
    included_groups = []
    if evt && evt[:filters]
      # parse the filters parameter
      (filter_groups = evt[:filters].split('|')).each do |f|
        filter_parts = f.split('-')
        filter_group = filter_parts.shift
        passed_filters << [filter_group, filter_parts]
        included_groups << filter_group
      end
    end
    # if there was no prior filter group, start with the defaults.
    if passed_filters.size == 0 || evt[:filters][0] == '|'[0]
      filter_default.keys.each do |fg|
        passed_filters.unshift [fg, filter_default[fg]]
      end
    end
    # verify the filters, make delta changes
    passed_filters.each do |group, filter_ids|
      if filter_sequence.include?(group)
        return_filters[group] ||= []
        filter_ids.each do |filter_id|
          if filters[group][:sequence].include?(filter_id)
            if filters[group][:options].has_key?(:exclusive)
              return_filters[group] = return_filters[group].include?(filter_id) ? [] : [filter_id]
            else
              if return_filters[group].include?(filter_id)
                return_filters[group].delete(filter_id)
              else
                return_filters[group] << filter_id
              end
            end
          end
        end
      end
    end
    (return_filters.size > 0) ? return_filters : nil
  end
  
  private 
  
  # set the sorting order based on the event parameters
  # relies on #grid_get_sort defined in jqgrid_support
  # magic: the :sortable column can be true if sortable, false if not sortable,
  # OR ['asc string','desc string'] which gets used in the order method.
  def use_sort(query, evt)
    sort_index, sort_order = grid_get_sort(evt)
    if sortable_columns[sort_index]
      column = columns[sortable_columns[sort_index]]      
    else
      if default_sort
        column = columns[sortable_columns[default_sort[0]]]
        sort_order = default_sort[1] ? 'ASC' : 'DESC'
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
          query = query.order("#{x.join('.')} #{sort_order}")
        else
          query = query.order("#{column[:field]} #{sort_order}")
        end
      else
        # custom override, presuming it is an array
        query = query.order(column[:sortable][sort_order == 'DESC' ? 1 : 0])
      end
    end
    query
  end
  
  # set the filtering based on event parameters
  def use_filter(query, evt)
    active_filters = parse_filters(evt)
    if active_filters && active_filters.size
      active_filters.each do |group,filter_ids|
        fg_options = filters[group][:options]
        query = query.where(fg_options[:where].call(filter_ids)) if fg_options.has_key?(:where) && filter_ids.size > 0
        query = query.joins(fg_options[:joins]) if fg_options.has_key?(:joins)
        filter_ids.each do |f|
          f_options = filters[group][:filters][f]
          query = query.where(f_options[:where]) if f_options.has_key?(:where)
          query = query.joins(f_options[:joins]) if f_options.has_key?(:joins)
        end
      end
    end
    query
  end
  
  # return what is appropriate given the pagination (that is, DO THE QUERY)
  # this has to be called last, of course, if it is going to take into account the filtering etc.
  # If there is no pagination, this just amounts to query.all
  # It will set the pagination instance variables as well.
  # relies on grid_get_pagination defined in jqgrid_support
  def use_pagination(query, evt)
    if grid_options[:pager]
      @current_page, rows = grid_get_pagination(evt)
      # is this expensive?  Seems like it should be.
      @total_records = query.count
      rows = @total_records if rows < 0
      @total_pages = @total_records == 0 ? 1 : ((@total_records-1)/rows)+1
      query = query.offset((@current_page-1)*rows)
      query = query.limit(rows)
    else
      @current_page = 1
      @total_pages = 1
      @total_records = query.count
    end
    query.all
  end
  
  # create local accessors for the configuration options known by the parent
  # seems cleaner to do this somehow
  
  def dom_id
    parent.dom_id
  end

  def grid_options
    parent.grid_options
  end

  def resource
    Object.const_get parent.options[:resource].classify
  end
  
  def includes
    parent.includes
  end
  
  def where
    parent.where
  end
  
  def sortable_columns
    parent.sortable_columns
  end
  
  def columns
    parent.columns
  end
  
  def default_sort
    parent.default_sort
  end
  
  def filters
    parent.filters
  end

  def filter_sequence
    parent.filter_sequence
  end

  def filter_default
    parent.filter_default
  end

  def filters_widget
    parent.filters_widget
  end
  
  def sanitize_request(evt)
    parent.sanitize_request(evt)
  end
  
  public :filters_widget, :dom_id  # view needs to be able to see these
  
end
