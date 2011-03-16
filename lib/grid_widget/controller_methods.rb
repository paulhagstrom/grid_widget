module GridWidget
  module ControllerMethods
    include GridWidget::JqgridSupport::ControllerMethods

    # Create a grid edit widget and set the default parameters
    # This should be called with a block, which will be called on the new widget to set
    # the configuration options.
    # if this is going to be a form_only widget, the form_only option should be sent as an opt
    def grid_edit_widget(resource, opts = {})
      opts[:resource] = resource
      opts[:widget_id] ||= resource
      w = widget(:grid_edit, opts[:widget_id], opts)
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