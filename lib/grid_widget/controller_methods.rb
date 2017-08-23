# These are methods for the creation of GridEditWidgets
# This should be mixed into controllers that have such widgets, and into
# GridEditWidgets themselves.
# 
module GridWidget
  module ControllerMethods
    include GridWidget::JqgridSupport::ControllerMethods

    # Create a grid edit widget and set the default parameters
    # This should be called with a block, which will be called on the new widget to set
    # the configuration options.
    # if this is going to be a form_only widget, the form_only option should be sent as an opt
    # If there are going to be multiple widgets with the same resources, :dom_id should be passed (will default to the resource)
    # Updated for apotomo 1.2.
    def grid_edit_widget(resource, opts = {})
      opts[:resource] = resource
      opts[:widget_id] ||= resource
      opts[:dom_id] ||= opts[:widget_id]
      w = widget(:grid_edit, opts[:widget_id], opts) do |wid|
        yield wid if block_given?
      end
      w
    end
    
    # I am pretty sure this is obsolete or something half-done
    # # #embed_widget is used to embed a subordinate grid_edit_widget into the form of this one.
    # # In the form, you would put, e.g., <%= rendered_children['contact_widget'] %> to specify the
    # # place where the sub-widget will appear.
    # # Intended to be called from either a controller or another GridEditWidget (e.g., in after_initialize)
    # # This is called with a 'where' clause that will be used when the records are loaded.
    # # It should be a lambda function which is passed an id, e.g., lambda {|x| {:person_id => x}}
    # # The 'where' clause is required, it tells the widget that it is subordinate.
    # def embed_widget(where, widget)
    #   self << widget
    #   widget.where = where
    #   self.respond_to_event :recordUpdated, :from => widget.name, :with => :redisplay, :on => self.list_widget_id
    #   self.respond_to_event :recordSelected, :from => widget.name, :with => :display_form, :on => self.name
    # end

  end

end