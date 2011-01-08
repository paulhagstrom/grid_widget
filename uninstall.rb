puts "Removing jqGrid, jquery, jqueryui javascripts and stylesheets from the grid_widget directories..."

FileUtils.remove_dir(js_dir = Rails.root.join('public', 'javascripts', 'grid_widget'))
FileUtils.remove_dir(css_dir = Rails.root.join('public', 'stylesheets', 'grid_widget'))

puts "Files removed."
