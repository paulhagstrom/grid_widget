# GridEditWidget is the main widget, has the form and has GridListWidget as a child.
#
# This can be used in a controller in the following way, where 'contact' is the name of
# a resource.  #grid_edit_widget is defined in grid_widget.rb.
#
#   include JqgridSupport::Controller
#   include Apotomo::Rails::ControllerMethods
# 
#   has_widgets do |root|
#     root << grid_edit_widget('contact') do |c|
#       [...configuration options...]
#     end
#   end
#
# The resource should be the name of a model, in underscore form.  It is used
# to retrieve the records for display.  A couple of further options can be
# placed after resource as parameters.  The widget_id will be resource_widget
# unless :widget_id is set explicitly.  You can pass other options, which will be
# passed on to apotomo's widget, and could, for example, be used in app-defined mixins.
#
#     root << grid_edit_widget('contact', :widget_id => 'wid', :beer => :insufficient) do |c|
#       [...configuration options...]
#     end
#
# Configuration options come in several types:
#   Grid DOM id:: Use dom_id (attribute), defaults to resource_widget (like widget_id)
#   Grid options:: Use grid_options (attribute)
#   Column options:: Use add_column
#   Query options:: Use includes (attribute)
#   Filter options:: Use add_filter_group and add_filter to create
#   Custom output methods:: Define as usual in the passed block
#   Form template name:: Use form_template (attribute),
#  looks in app/cells/grid_form_widget/form/ for {form_template}.html.erb, and
#  defaults to {controller}.
#   Where clause for sub-widgets:: Use where (attribute), define with lambda expecting parent id.
#
# They can all be set in a single configuration block and intermixed, though order
# does matter when defining columns and filters.
#
# For example:
#
#   has_widgets do |root|
#     root << grid_edit_widget('contact') do |c|
#       c.grid_options {:title => 'Contacts list'}
#       c.has_includes :categories
#       c.add_column('name', :custom => :custom_name)
#       def c.custom_name(name)
#         "[#{name}]"
#       end
#       c.add_filter_group('categories', :where => lambda {|x| {category_id => x}}) do |g|
#         Category.all.each {|cat| g.add_filter(cat.id, cat.name)}
#       end
#     end
#   end
#
# Columns can have custom output methods, defined in the configuration block.
# There are a couple of these methods already defined here that can be used.
# 
# * :custom_yn (for booleans, display 'Yes' if true otherwise 'No')
# * :custom_check (like :custom_yn, but displays a checkmark or nothing)
# * :custom_abbrev (for long strings, cuts it off at 20 characters and provides ellipses)
class GridEditWidget < Apotomo::Widget
  include GridWidget::Controller
  include AppSupport::Controller
  
  attr_accessor :includes
  attr_accessor :grid_options
  attr_accessor :dom_id
  attr_accessor :form_template
  attr_accessor :where
  attr_accessor :record
  attr_reader :resource
  attr_reader :columns, :sortable_columns, :default_sort
  attr_reader :filters, :filter_sequence
  attr_reader :filter_default
  
  after_initialize :setup

  # TODO: Try this later
  # responds_to_event :formSubmit, :with => :form_submitted
  
  after_add do |me, parent|
    me.respond_to_event :formSubmit, :from => me.name, :with => :form_submitted, :on => me.name
  end
  
  # Draw the empty form (and the child list widget, which will render first)
  def display
    render
  end
  
  # #display_form catches the :recordSelected event that originates from the list #cell_click method.
  # Emits the JS to populate and reveal the form.
  def display_form
    @record = fetch_record
    # Make a new form div so we can slide away the old one and swap ids
    # (This all relies on the id of the form corresponding to an enclosing div, incidentally)
    form = @dom_id + '_form'
    clone_form = <<-JS
    var new_form = $('##{form}').clone().hide().css('background-color','#DDDDFF');
    $('##{form}').attr('id', 'ex_#{form}');
    $('#ex_#{form}').find('[id]').attr('id', function(){return 'ex_' + this.id;});
    // These elements are no more.  They have ceased to be.  Bereft of life, they rest in peace.
    // This is an ex_form!
    new_form.insertAfter('#ex_#{form}');
    JS
    # slide in the new one and slide out and destroy the old one
    swap_display = <<-JS
    $('##{form}').slideDown('fast');
    $('#ex_#{form}').slideUp('fast', function() { $(this).remove();});
    JS
    render :text => clone_form + 
      update(:selector => @dom_id + '_form', :view => 'form/' + @form_template, :layout => 'form_wrapper', :locals =>
        {:container => @dom_id + '_form', :resource => @resource, :record => @record}) +
      ';' + swap_display
  end
  
  # #form_submitted catches the :formSubmit event from the form (defined in the form_wrapper layout).
  # Updates the record with attributes in the (@dom_id + '_form') hash (default: resource_widget_form)
  def form_submitted
    # TODO: Check. This might be a bit insecure at the moment 
    if param(:form_action) == 'submit'
      record = fetch_record
      record.update_attributes(param(@dom_id + '_form'))
      record.save
      trigger :recordUpdated
      render :text => turn_and_deveal_form
    else
      render :text => turn_and_deveal_form('#FF8888')
    end
  end
  
  # Forms the Javascript that will change the background color of the form and slide it away.
  # This is included in the responses to hitting update or cancel.
  # The color is supposed to signal whether it is an update or a cancel (default is green for update).
  # TODO: Use CSS
  def turn_and_deveal_form(color = '#88FF88')
    form = @dom_id + '_form'
    <<-JS
    $('##{form}').css('background-color','#{color}').slideUp('fast');
    JS
  end

  # #delete_record catches the :deleteRecord event posted by the grid when the delete button is hit.
  # Deletes the selected record, cancels the form, and posts :recordUpdated to get the list to redraw.
  def delete_record
    if record = fetch_record
      record.destroy
    end
    trigger :recordUpdated
    render :text => turn_and_deveal_form('#FF8888')
  end
  
  # #edit_record catches the :editRecord event posted by the grid for editing in place.
  # At this point, it only handles toggling boolean values.
  # TODO: Allow for other editing in place.
  # When an in-place edit happens, the form is canceled because it *could* have been the one we
  # were editing.
  # TODO: Make this smarter so that it will cancel the form only if it *is* the one we are editing.
  # TODO: Or make it even smarter and have it update the value in the form rather than cancel.
  def edit_record
    c = @columns[param(:col).to_i]
    if c[:inplace_edit]
      record = fetch_record
      if c[:toggle]
        f = c[:field]
        v = record.send(f)
        record.update_attributes({f => !v})
      end
      record.save
      trigger :recordUpdated
      render :text => turn_and_deveal_form('#FF8888')
    else
      render :nothing => true
    end
  end
  
  # #fetch_record loads either a new record or the record for which an ID was passed.
  # TODO: Should #fetch_record be private?  
  def fetch_record
    if param(:id).to_i > 0
      record = (Object.const_get @resource.classify).includes(@includes).find(param(:id))
    else
      if @where
        record = (Object.const_get @resource.classify).where(@where.call(param(:pid))).new
      else
        record = (Object.const_get @resource.classify).new
      end
    end
  end

  # Add a column to the column model for the grid.  This will include things like the label and field, any
  # special display options.  The +field+ option is required, and several things are guessed from that
  # if not provided.  This is intended to be called as part of the configuration block of grid_edit_widget.
  #
  # * +field+ is evaluated (in Rails) to get the value (e.g., last_name, or person.last_name).
  # * +name+ is a unique identifier used by the grid, defaults to +field+ with dots replaced by underscores.
  # * +sortable+ is true is a column is sortable, false otherwise.  A string can be provided instead,
  #   which will go directly into the order clause of the query.  Defaults to false.
  # * +index+ is the name of a sortable column, defaults to +name+
  # * +label+ is what the header displays, defaults to humanized +name+.
  # * +width+ is the width of the column, defaults to 100.
  # * +search+ is true when a column is searchable; it is a jqGrid option that I don't use (yet).  Defaults to false.
  # * +classes+ are CSS classes that will be applied to cells in the column
  # * +open_panel+ is true if a cell click will open the edit panel, it is matched to css style column_opens_panel
  # * +inplace_edit+ is true if a cell click will result in an inplace edit, matched to css column_inplace_edit
  # * +toggle+ is true if the column represents a boolean that will be toggled, goes with inplace_edit
  # * +default+ is set to true on the column that will be the default sort, false for descending.
  #   (no default will result in the first sortable column being selected, ascending)
  def add_column(field, options = {})
    # grid options
    options[:name] ||= field.sub('.', '_')
    options[:sortable] = false unless options.has_key?(:sortable)
    options[:index] ||= options[:name] if options[:sortable]
    options[:label] ||= options[:name].humanize
    options[:width] ||= 100
    options[:search] = false unless options.has_key?(:search)
    # local options
    options[:field] = field
    options[:inplace_edit] = true if options[:toggle]
    if options[:open_panel] || options[:inplace_edit]
      options[:classes] ||= [
        (options[:open_panel] ? 'column_opens_panel' : nil),
        (options[:inplace_edit] ? 'column_inplace_edit' : nil)
      ].compact.join(' ')
    end
    if options[:sortable]
      if options.has_key?(:default)
        @default_sort = [options[:index], options[:default]]
      else
        @default_sort = [options[:index], true] unless @default_sort
      end
      @sortable_columns[options[:index]] = @columns.size
    end
    @columns << options
  end  

  # A filter group groups together filters.  All filters must be in a filter group.
  # For certain filters, where or joins might apply to all of the filters in the group
  # Those are provided in the options (:where, :joins).
  #
  # NOTE that the :where clause here takes a parameter (called as ...[:where].call(values)).
  # The values used are the identifiers of the filters within, assumed to be integers (record ids)
  #
  # The +id+ is a short string identifying the group, and the displayed name is by default the humanized version.
  # You can provide :name as an option instead.
  #
  # If you provide :exclusive, then only one choice in the filter group can be made at a time.
  #
  # For the display, you can specify +:columns => n+, which is the number of columns the display table has.
  #
  # Internally, :sequence is an array of the identifying keys of the filters within (in order)
  # and :filters has the individual filters' options
  def add_filter_group(id, options = {}) # :yields: self
    options[:name] ||= id.humanize
    @current_filter_group = id
    @filters[id] = {:options => options, :sequence => [], :filters => {}}
    @filter_sequence << id
    yield self if block_given?
    self
  end
  
  # A filter (within a filter group) itself has an id, name, and options.
  # It can contain its own joins and where clauses.
  # They will be composed with the filter groups' if both have them.
  # The where clause here does NOT take a parameter, unlike the filter group's.
  # :name is the display name, it will be the humanized id unless you specify it
  # This can be called with a simple string, in which that is taken to be the name
  # If you provide :default, then this filter will be active by default
  #--
  # Maybe: add a :set_filters option to allow setting the state of other filters (a macro of a sort)
  # Maybe: add a way to set the ordering as well as a reaction to a filter.
  def add_filter(id, options = {})
    options = {:name => options} if options.is_a?(String)
    options[:name] ||= id.humanize
    @filters[@current_filter_group][:filters][id.to_s] = options
    @filters[@current_filter_group][:sequence] << id.to_s
    @filter_default << [@current_filter_group,id] if options.has_key?(:default)
  end
  
  # TODO: Move the custom display methods into their own module
  
  # Custom display method to abbreviate a long string
  def custom_abbrev(long_string)
    long_string[0..20] + (long_string.size > 10 ? '...' : '') rescue ''
  end

  # Custom display method for booleans: Yes if true, otherwise no
  def custom_yn(value)
    value ? 'YES' : 'No'
  end

  # Custom display method for booleans: check if true, otherwise nothing, using jQuery UI
  def custom_check(value)
    value ? '<span class="ui-icon ui-icon-check"></span>' : ''
  end
  
  # #embed_widget is used to embed a subordinate grid_edit_widget into the form of this one.
  # In the form, you would put, e.g., <%= rendered_children['contact_widget'] %> to specify the
  # place where the sub-widget will appear.
  # Intended to be called from either a controller or another GridEditWidget (e.g., in after_initialize)
  # This is called with a 'where' clause that will be used when the records are loaded.
  # It should be a lambda function which is passed an id, e.g., lambda {|x| {:person_id => x}}
  # The 'where' clause is required, it tells the widget that it is subordinate.
  def embed_widget(where, widget)
    self << widget
    widget.where = where
  end
  
  # #get_request_parameters inspects the request parameters, mostly to sanitize and update
  # the filters.  It will also catch the parent's id (for subordinate forms).
  #
  # Filter parameters come in as a string in :filters in the following format:
  # filters = group1-val1-val2-val3|group2-vala-valb-valc|group1-val4
  # if a group repeats, the later values toggle existing, e.g., above group1 will have val4
  # if it had ended in group1-val2, then val2 would have been removed from group1
  # TODO: Investigate using real arrays, it would be simpler than having to parse this much.
  def get_request_parameters
    return_filters = {}
    return_params = param(:pid) ? {:pid => param(:pid)} : {}
    if param(:filters)
      # parse the filters parameter
      filters = []
      (filter_groups = param(:filters).split('|')).each do |f|
        filter_parts = f.split('-')
        filter_group = filter_parts.shift
        filters << [filter_group, filter_parts]
      end
      # verify the filters, make delta changes
      filters.each do |group, filter_ids|
        if @filter_sequence.include?(group)
          return_filters[group] ||= []
          filter_ids.each do |filter_id|
            if @filters[group][:sequence].include?(filter_id)
              if @filters[group][:options].has_key?(:exclusive)
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
    end
    unless return_filters.size > 0
      # No (valid) filters, so return the default if there is one
      @filter_default.each do |df|
        g, f = df
        return_filters[g] ||= []
        return_filters[g] << f
      end
    end
    return_params[:filters] = (return_filters.size > 0) ? return_filters : nil
    return_params
  end
  
  private
  
  # Called by after_initialize, will set the defaults prior to executing the configuration block.
  def setup(*)
    @resource = param(:resource)

    @dom_id = @resource + '_widget'

    @grid_options = {}
    
    @columns = []
    @sortable_columns = {}
    @default_sort = nil
    
    @filters = {}
    @filter_sequence = []
    @filter_default = []
    
    # Guesses that you will be using the form template matching the name of your controller
    # This can be overridden in the configuration, but defaults to 'authors' for AuthorsController
    @form_template = parent_controller.class.name.underscore.gsub(/_controller$/,'')
    
    # create the child list widget
    self << widget(:grid_list_widget, @dom_id + '_list', :display)
  end
end
