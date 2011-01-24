# These are the helper methods for configuring a GridWidget.
# They are mixed into GridEditWidget.
# 
# The methods here provide an interface for setting up the column model that will
# be used for the grid, and setting up the filters.
#
module GridWidget
  module ConfigMethods
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
  end
end