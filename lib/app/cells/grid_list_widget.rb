class GridListWidget < Apotomo::Widget
  include GridWidget::Controller
  include AppSupport::Controller
  helper GridWidget::Helper
  helper AppSupport::Helper
  
  # This seemed to get caught up in a cache somewhere, so I moved this into
  # the after_add block.
  # responds_to_event :fetchData, :with => :send_json
  # responds_to_event :cellClick, :with => :cell_click
  
  after_add do |me, parent|
    me.respond_to_event :fetchData, :with => :send_json, :on => me.name
    me.respond_to_event :cellClick, :with => :cell_click, :on => me.name
    parent.respond_to_event :recordUpdated, :with => :redisplay, :on => me.name
    parent.respond_to_event :filterSelected, :with => :set_filter, :on => me.name
    @parent = parent
    @resource = parent.resource
    @container = parent.name    
  end
    
  # This needs to be updated so that it can do pagination and live search
  # TODO: Maybe allow custom sorts depending on the column selected -- to do common subordering.
  # TODO: Consider whether filters should specify ordering, or maybe default ordering
  def load_records
    q = (Object.const_get @resource.classify).scoped

    # sorting
    sort_index = param(:sidx)
    sort_order = (param(:sord) == 'desc') ? 'DESC' : 'ASC'
    if @parent.sortable_columns[sort_index]
      column = @parent.columns[@parent.sortable_columns[sort_index]]      
    else
      if @parent.default_sort
        column = @parent.columns[@parent.sortable_columns[@parent.default_sort[0]]]
        sort_order = @parent.default_sort[1] ? 'ASC' : 'DESC'
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
    q = q.includes(@parent.includes) if @parent.includes
    
    # filtering
    if filters = get_filter_parameters
      filters.each do |group,filter_ids|
        fg_options = @parent.filters[group][:options]
        q = q.where(fg_options[:where].call(filter_ids)) if fg_options.has_key?(:where) && filter_ids.size > 0
        q = q.joins(fg_options[:joins]) if fg_options.has_key?(:joins)
        filter_ids.each do |f|
          f_options = @parent.filters[group][:filters][f]
          q = q.where(f_options[:where]) if f_options.has_key?(:where)
          q = q.joins(f_options[:joins]) if f_options.has_key?(:joins)
        end
      end
    end

    # I should do more error checking here I think.
    if @parent.grid_options[:rows]
      # is this expensive?
      @total_records = q.count
      @page, @shown_rows = [param(:page).to_i, param(:rows).to_i]
      @page = 1 if @page < 1
      @shown_rows = @parent.grid_options[:rows] if @shown_rows < 1
      q = q.offset((@page-1)*@shown_rows)
      q = q.limit(@shown_rows)
    end
    
    # get them
    @records = q.all
    
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
  
  def display
    load_records
    @set_filters = self.set_filter
    render
  end
  
  def redisplay
    render :text => "$('##{@container + '_grid'}').trigger('reloadGrid');"
  end

  def send_json
    load_records
    render :text => grid_json(@records).to_json
  end
  
  def cell_click
    if @parent.columns[param(:col).to_i][:inplace_edit]
      trigger :editRecord, :id => param(:id), :col => param(:col)
    else
      trigger :recordSelected, :id => param(:id)
    end
  end
  
  def set_filter
    # Turn off all the filters, then turn on the active ones
    x = ''
    filter_parms = []
    groups_active = []
    if filters = get_filter_parameters
      filters.each do |group,filter_ids|
        filter_parm = group
        filter_ids.each do |filter_id|
          x += <<-JS
          $('#filter_#{@parent.name}_#{group}_#{filter_id}').addClass('filter_on').removeClass('filter_off').removeClass('filter_onf');
          JS
          filter_parm += '-' + filter_id.to_s
        end
        filter_parms << filter_parm
        groups_active << group if filter_ids.size > 0
      end
    end
    group_style = ''
    @parent.filter_sequence.each do |f|
      if groups_active.include?(f)
        group_style += <<-JS
        $('##{@parent.name}_list .filter_#{f}').removeClass('filter_on').addClass('filter_off').removeClass('filter_onf');
        JS
      else
        group_style += <<-JS
        $('##{@parent.name}_list .filter_#{f}').removeClass('filter_on').removeClass('filter_off').addClass('filter_onf');
        JS
      end
    end
    render :text => group_style + x + grid_set_filter_parms({'filters' => filter_parms.join('|')}) + self.redisplay
  end
  
  private 
  
  # filter parameters come in like this:
  # filters = group1-val1-val2-val3|group2-vala-valb-valc|group1-val4
  # if a group repeats, the later values toggle existing, e.g., above group1 will have val4
  # if it had ended in group1-val2, then val2 would have been removed from group1
  def get_filter_parameters
    return_filters = {}
    if param(:filters)
      # split the HTTP parameter
      filters = []
      (filter_groups = param(:filters).split('|')).each do |f|
        filter_bits = f.split('-')
        filter_group = filter_bits.shift
        filters << [filter_group, filter_bits]
      end
      # collect values, verify, make delta changes
      filters.each do |group, filter_ids|
        if @parent.filter_sequence.include?(group)
          return_filters[group] ||= []
          filter_ids.each do |filter_id|
            if @parent.filters[group][:sequence].include?(filter_id)
              if @parent.filters[group][:options].has_key?(:exclusive)
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
      # return return_filters.size > 0 ? return_filters : nil
    end
    unless return_filters.size > 0
      # No (valid) filters, so return the default if there is one
      @parent.filter_default.each do |df|
        g, f = df
        return_filters[g] ||= []
        return_filters[g] << f
      end
    end
    (return_filters.size > 0) ? return_filters : nil
  end
  
  # # replace v_from in a hash with v_to
  # # I am going to try to do this in another way, but for the record.
  # # newhash = hash_replace(oldhash, value to find, value to replace)
  # # e.g., newhash = hash_replace(oldhash, :V, [1, 2, 3])
  # def hash_replace(hash_from, v_from, v_to)
  #   hash_to = {}
  #   hash_from.each do |k,v|
  #     v = v_to if v == v_from
  #     v = hash_replace(v,v_from,v_to) if v.is_a?(Hash)
  #     hash_to[k] = v
  #   end
  #   hash_to
  # end
  
end
