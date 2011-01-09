# These modules are included by the widgets
# There is quite probably a better way to do this. 
# The idea is that you can put something like the following in your, say, admin_helper
# and then just do helper :admin in the controller that creates the grid_edit_widget
# It does seem to work, but it also seems circuitous.
# I have yet to find a use for the AppSupport::Controller module, but it is there.
# 
# module AdminHelper
#   module ::AppSupport
#     module Controller
#       [...methods you want mixed into the widget controller...]
#     end
# 
#     module Helper
#       [...methods you want mixed into the helper for the widget...]
#       def print_four
#         4
#       end
#     end
#   end
# end

module AppSupport
  module Controller
  end

  module Helper
  end
end