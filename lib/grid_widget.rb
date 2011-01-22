# These are basic support methods to be mixed in with application controllers, widgets,
# and helpers.  The things defined in this file are more general, for the creation of
# widgets, and handling of filters.  The methods that work specifically with the grid
# are defined in +jqgrid_support+, so that in principle a parallel module could be written
# to support the use of a grid other than jQGrid.  Currently, there is no option, and
# jQGrid is simply required.
#
# Controllers should contain the lines
#
#   include Apotomo::Rails::ControllerMethods
#   include GridWidget::ControllerMethods
#

# The GridWidget module mixes in relevant controller and helper methods
module GridWidget
  # Later I might allow for some kind of configuration to choose the grid.  For now: jqGrid.
  require 'grid_widget/app_support'
  require 'grid_widget/jqgrid_support'
  require 'grid_widget/controller_methods'
  require 'grid_widget/helper_methods'
  require 'grid_widget/config_methods'
  
  module ControllerMethods
    # Include the plugin-internal paths, so that the views in lib/app/cells are locatable.
    Cells.setup do |config|
      config.append_view_path File.join(File.dirname(__FILE__), 'app', 'cells')
    end    
  end
  
  require 'app/cells/grid_edit_widget'
  require 'app/cells/grid_list_widget'

end