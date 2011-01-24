# These are methods for the creation of GridEditWidgets
# This should be mixed into controllers that have such widgets, and into
# GridEditWidgets themselves.
# 
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
      self.respond_to_event :recordUpdated, :from => widget.name, :with => :redisplay, :on => self.list_widget_id
      self.respond_to_event :recordSelected, :from => widget.name, :with => :display_form, :on => self.name
    end

    # TODO add support for Boxes https://github.com/Orion98MC/Boxes
    # def box_configure_form
    #   @wopts = @options.clone
    #   render
    # end
  end

end