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
  
  # Draw the empty form and list
  def display
    render
  end
  
  # catch the :recordSelected event, originates from the list.
  # send the JS to populate and reveal the form.  Uses #display_form
  def reveal_form
    # Make a new form div so we can slide away the old one and swap ids
    # (This all relies on the id of the form corresponding to an enclosing div, incidentally)
    # Forcibly remove any jqgrids still there or there will be a problem loading the new one
    form = @dom_id + '_form'
    clone_form = <<-JS
    $('##{form}').clone().hide().css('background-color','#DDDDFF').attr('id','new_#{form}').insertAfter('##{form}');
    $('##{form}').attr('id', 'ex_#{form}');
    $('#ex_#{form} .ui-jqgrid').remove();
    $('#new_#{form}').attr('id', '#{form}');
    JS
    # slide in the new one and slide out and destroy the old one
    swap_display = <<-JS
    $('##{form}').slideDown('fast');
    $('#ex_#{form}').slideUp('fast', function() { $(this).remove();});
    JS
    # This is kind of an internal use of a state, but, you know, it works.
    render :text => clone_form + self.display_form + ';' + swap_display
  end
  
  def display_form
    @record = fetch_record
    # TODO: Is parentSelection redundant?  Can't I just watch for :recordSelected?
    # trigger :parentSelection, :pid => @record.id
    # TODO: Try to pass fewer locals
    update :selector => @dom_id + '_form', :view => 'form/' + @form_template, :layout => 'form_wrapper', :locals =>
      {:container => @dom_id + '_form', :resource => @resource, :record => @record}
  end

  # TODO: Make this work.
  # # parent_selection handles the :parentSelected event that a form widget posts when a record is
  # # selected.  This receiver is active on a grid_edit_widget that is attached as a child to the
  # # form widget.
  # #
  # # Because this is being written stateless, we need to dispatch the new information to the grid,
  # # so that when it calls to reload its dataset it supplies the right parameters.
  # def parent_selection
  #   # @parent_record = @parent.record
  #   # trigger :recordUpdated
  #   render :text => grid_set_post_params(self.name, 'pid' => param(:pid)) + grid_reload + "/*parent_selection*/"
  # end
  
  # The form is looking for things in a (@dom_id + '_form') array, which will by default be self.name (resource_widget)
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
  
  def turn_and_deveal_form(color = '#88FF88')
    form = @dom_id + '_form'
    <<-JS
    $('##{form}').css('background-color','#{color}').slideUp('fast');
    $('##{form}').slideUp('fast');
    JS
  end

  def delete_record
    if record = fetch_record
      record.destroy
    end
    trigger :recordUpdated
    render :text => turn_and_deveal_form('#FF8888')
  end
  
  # edit in place.  Right now, use only for toggles.
  # If you edit in place, it will cancel the form if it is open.
  # Later someday maybe I can make it reload or modify the form if the id matches.
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
  
  # TODO: Should #fetch_record be private?
  
  def fetch_record
    if param(:id).to_i > 0
      record = (Object.const_get @resource.classify).includes(@includes).find(param(:id))
    else
      record = (Object.const_get @resource.classify).new
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
  
  # Abbreviate a long string for display
  def custom_abbrev(long_string)
    long_string[0..20] + (long_string.size > 10 ? '...' : '') rescue ''
  end

  # Yes if true, otherwise no
  def custom_yn(value)
    value ? 'YES' : 'No'
  end

  # check if true, otherwise nothing, using jQuery UI
  def custom_check(value)
    value ? '<span class="ui-icon ui-icon-check"></span>' : ''
  end
  
  # TODO: Make this work.
  # The idea is that you are embedding another grid_edit_widget into this one.
  def embed_widget(where, widget)
    self << widget
    widget.where = where
    # self.respond_to_event :parentSelection, :from => self.name, :with => :parent_selection, :on => widget.name
  end
  
  private
  
  # Called by after_initialize, will set the defaults prior to executing the configuration block.
  def setup(*)
    @resource = param(:resource)
    # Removing container as unnecessary.  widget_id should be available in the views.
    # @container = self.name

    @dom_id = @resource + '_widget'

    @grid_options = {}
    
    @columns = []
    @sortable_columns = {}
    @default_sort = nil
    
    @filters = {}
    @filter_sequence = []
    @filter_default = []
    
    # TODO: See if there's a better way to get the controller.  For example #controller?
    @form_template = params[:controller]
    
    # create the child list widget
    self << widget(:grid_list_widget, @dom_id + '_list', :display)
  end
end
