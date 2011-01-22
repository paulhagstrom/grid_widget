# These modules are included by the widgets
# There is quite probably a better way to do this. 
# The idea is that you can put something like the following in your, say, admin_helper
# and then just do helper :admin in the controller that creates the grid_edit_widget
# It does seem to work, but it also seems circuitous.
# I have yet to find a use for the GridWidget::AppSupport::ControllerMethods module, but it is there.
# 
# module AdminHelper
#   module ::GridWidget::AppSupport
#     module ControllerMethods
#       [...methods you want mixed into the widget controller...]
#     end
# 
#     module HelperMethods
#       [...methods you want mixed into the helper for the widget...]
#       def print_four
#         4
#       end
#     end
#   end
# end

module GridWidget
  module AppSupport
    module ControllerMethods
    end

    module HelperMethods
    end
  end
end
