require 'jqgrid_support'

# The GridWidget module mixes in relevant controller and helper methods
# Note that for these to be included properly, the following line needs to be in config/application.rb
# config.autoload_paths += %W(#{config.root}/lib/grid_edit)
module GridWidget
  module Controller
    # Later I might allow for some kind of configuration to choose the grid.  For now: jqGrid.
    include JqgridSupport::Controller

    # Include the plugin-internal paths, so that the views in lib/app/cells are locatable.
    Cells.setup do |config|
      config.append_view_path File.join(File.dirname(__FILE__), 'app', 'cells')
    end
    
    # create a grid edit widget and set the default parameters
    # This should be called with a block, which will be called on the new widget to set
    # the configuration options.
    def grid_edit_widget(resource, options = {})
      options[:resource] = resource
      options[:widget_name] ||= resource + '_widget'
      options[:dom_id] ||= resource + '_widget'
      options[:start] ||= :display
      options[:title] ||= resource.pluralize.humanize
      options[:cell_class] ||= :grid_edit_widget
      w = widget(options[:cell_class], options[:widget_name], options[:start], options)
      yield w if block_given?
      w
    end 
  end
  
  module Helper
    # Later I might allow for some kind of configuration to choose the grid.  For now: jqGrid.
    include JqgridSupport::Helper
    
    # I seem to have to do this to get url_for_event working well under a relative path.
    # I probably shouldn't have to
    def rurl_for_event(type, options = {})
      options[:controller] = (ENV['RAILS_RELATIVE_URL_ROOT'] ? ENV['RAILS_RELATIVE_URL_ROOT'] + '/' : '') + params[:controller]
      url_for_event(type, options)
    end

    # wire_filters adds the Javascript watchers to the elements of the filter UI
    # When a filter is clicked, it will call build_filter (defined by #grid_define_get_filter_parms)
    # to append the new selection to the existing selection, and trigger a :filterSelected
    # event that GridListWidget will respond to.
    def wire_filters
      wiring = <<-JS
      $('##{@parent.name}_list .filter').hover(function(){
          $(this).addClass('filter_hover');
        },function(){
          $(this).removeClass('filter_hover');
        });
      JS
      wiring += grid_define_get_filter_parms
      @parent.filter_sequence.each do |filter_group|
        f = @parent.filters[filter_group]
        f[:sequence].each do |sf|
          wiring += <<-JS
          $('#filter_#{@parent.name}_#{filter_group}_#{sf}').click(function(){
      			$.get('#{rurl_for_event(:filterSelected)}', build_filter_#{@parent.name}('#{filter_group}','#{sf}'), null, 'script');
            });
          JS
        end
      end
      javascript_tag wiring
    end
    
  end
  
  require 'app/cells/grid_edit_widget'
  require 'app/cells/grid_list_widget'
  require 'app/cells/grid_form_widget'

end