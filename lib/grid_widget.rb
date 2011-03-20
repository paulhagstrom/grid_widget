# These are basic support methods to be mixed in with application controllers, widgets,
# and helpers.  The things defined in this file are more general, for the creation of
# widgets, and handling of filters.  The methods that work specifically with the grid
# are defined in +jqgrid_support+, so that in principle a parallel module could be written
# to support the use of a grid other than jQGrid.  Currently, there is no option, and
# jQGrid is simply required.
#
# Controllers should contain the lines
#
#   include GridWidget::ControllerMethods
#
# TODO: The GridWidget name is not great, because it results in a grid_widget.rb
# which is NOT an apotomo widget.  I should consider renaming this.  Possibilities
# include grid_widgets, since that's really what it is, a collection of widgets
# to implement a grid.  First I will get it working, then I will consider renaming.

module GridWidget
  require 'grid_widget/app_support'
  require 'grid_widget/jqgrid_support'
  require 'grid_widget/controller_methods'
  require 'grid_widget/helper_methods'
  require 'grid_widget/config_methods'
  
  module ControllerMethods
    # Include the plugin-internal paths, so that the views in lib/views are locatable.
    Apotomo::Widget.append_view_path File.join(File.dirname(__FILE__), 'app', 'widgets')
  end
  
  require 'app/widgets/grid_edit_widget'
  require 'app/widgets/grid_list_widget'
  require 'app/widgets/grid_filters_widget'
  require 'app/widgets/grid_flash_widget'

end