# encoding: utf-8
# copied from Formtastic generator, combined with my prior plugin install
# though it is largely based on the Rails generator docs itself.
# ultimately, this is not really critical, files can be copied (and updated) manually.
# Also, I made the decision to rename the js/css files so they do not contain version
# so that I can update more easily.
# wait, I don't even use these anymore.
# This is already way outdated.
# all it is installing is:
# jQGrid: jquery.jqGrid.min.js; grid.locale-en.js, ui.jqgrid.css
# jquery-ui: jqury-ui.min.js, jquery-ui.custom.css, images/
# jQuery: jquery.js
# backend.css <-- that one is the only one that really belongs here.
# jquery-ujs: rails.js 
# 
module GridWidget
  # Copies required javascript and stylesheets into public/grid_widget
  #
  # @example
  # !!!shell
  #   $ rails generate grid_widget:install
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('../../../stylesheets', __FILE__)
    class_option :template_engine

    desc "Copies grid_widget.css file to public/stylesheets"
    def copy_files
      copy_file 'grid_widget.css', 'public/stylesheets/grid_widget.css'
    end
    # source_root File.expand_path('../../../../public', __FILE__)
    # class_option could be used to provide command line arguments if needed someday

    desc "Installing jqGrid, jquery, jqueryui javascripts and stylesheets to public/"
    def copy_support_files
      # I think source_root and directory would allow me to make these copies but whatever.
      # This is just a direct copy from what I had in the old install.rb
      # directory 'stylesheets/grid_widget' 'public/stylesheets/grid_widget'
      # create or find the target directories
      FileUtils.mkdir_p(js_dir = Rails.root.join('public', 'javascripts', 'grid_widget'))
      FileUtils.mkdir_p(css_dir = Rails.root.join('public', 'stylesheets', 'grid_widget'))
      # find the source directories relative to this file.
      FileUtils.cp_r File.join(File.dirname(__FILE__), 'lib', 'public', 'javascripts'), js_dir
      FileUtils.cp_r File.join(File.dirname(__FILE__), 'lib', 'public', 'stylesheets'), css_dir
    end
  end
end


# Notes from back when this was a plugin in vendor/grid_widget:
# This was what was in install.rb

# puts "Installing jqGrid, jquery, jqueryui javascripts and stylesheets..."

# FileUtils.mkdir_p(js_dir = Rails.root.join('public', 'javascripts', 'grid_widget'))
# FileUtils.mkdir_p(css_dir = Rails.root.join('public', 'stylesheets', 'grid_widget'))

# puts "Copying Javascript to " + js_dir.to_s

# FileUtils.cp_r File.join(File.dirname(__FILE__), 'lib', 'public', 'javascripts'), js_dir

# puts "Copying Stylesheets and images to " + css_dir.to_s

# FileUtils.cp_r File.join(File.dirname(__FILE__), 'lib', 'public', 'stylesheets'), css_dir

# puts "Files copied."

# # This was what was in uninstall.rb

# puts "Removing jqGrid, jquery, jqueryui javascripts and stylesheets from the grid_widget directories..."

# FileUtils.remove_dir(js_dir = Rails.root.join('public', 'javascripts', 'grid_widget'))
# FileUtils.remove_dir(css_dir = Rails.root.join('public', 'stylesheets', 'grid_widget'))

# puts "Files removed."

