# GridEditWidget is the main widget, a container for GridFormWidget and GridListWidget.
# The design is such that GridEditWidget holds all the configuration information, which
# the form and list widgets retrieve via @parent.attribute.
#
# This can be used in a controller in the following way, where 'contact' is the name of
# a resource, see grid_edit_widget for what this means.
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
# Configuration options come in several types:
#   Grid options:: Use grid_options (attribute)
#   Column options:: Use add_column
#   Query options:: Use includes (attribute)
#   Filter options:: Use add_filter_group and add_filter to create
#   Custom output methods:: Define as usual in the passed block
#   Form template name:: Use form_template (attribute),
#  looks in app/cells/grid_form_widget/form/ for {form_template}.html.erb, and
#  defaults to {controller}.
#
# They can all be set in a single configuration block and intermixed, though order
# does matter when defining columns and filters.
#
# For example:
#
#   has_widgets do |root|
#     root << grid_edit_widget('contact') do |c|
#       c.grid_options {:title => 'Grid title'}
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
# There are a couple of custom display methods already defined here that can be used.
# They are
# * :custom_yn (for booleans, display 'Yes' if true otherwise 'No')
# * :custom_check (like :custom_yn, but displays a checkmark or nothing)
# * :custom_abbrev (for long strings, cuts it off at 20 characters and provides ellipses)
class GridEditWidget < Apotomo::Widget
  include GridWidget::Controller

  after_initialize :setup
  
  attr_reader :resource
  attr_accessor :includes
  attr_accessor :grid_options
  attr_reader :columns, :sortable_columns, :default_sort
  attr_reader :filters, :filter_sequence
  attr_reader :filter_default
  attr_accessor :form_template
  
  def display
    render
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
  
  private
  
  def setup(*)
    @resource = param(:resource)
    @container = self.name

    @grid_options = {}
    
    @columns = []
    @sortable_columns = {}
    @default_sort = nil
    
    @filters = {}
    @filter_sequence = []
    @filter_default = []
    
    @form_template = params[:controller]
    
    # create the list and form widgets
    self << lw = widget(:grid_list_widget, @container + '_list', :display)
    self << fw = widget(:grid_form_widget, @container + '_form', :display)
    # This was an attempt to add the controller paths, didn't work.
    # fw.view_paths.concat(ActionController::Base.view_paths)
  end
end
