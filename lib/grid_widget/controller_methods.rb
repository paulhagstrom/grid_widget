module GridWidget
  module ControllerMethods
    # Later I might allow for some kind of configuration to choose the grid.  For now: jqGrid.
    include GridWidget::JqgridSupport::ControllerMethods

    # create a grid edit widget and set the default parameters
    # This should be called with a block, which will be called on the new widget to set
    # the configuration options.
    def grid_edit_widget(resource, options = {})
      options[:resource] = resource
      options[:widget_id] ||= resource + '_widget'
      w = widget(:grid_edit_widget, options[:widget_id], :display, options)
      yield w if block_given?
      w
    end
    
    # TODO add support for Boxes https://github.com/Orion98MC/Boxes
    # def box_configure_form
    #   @wopts = @options.clone
    #   render
    # end
  end

end