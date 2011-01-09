puts "Installing jqGrid, jquery, jqueryui javascripts and stylesheets..."

FileUtils.mkdir_p(js_dir = Rails.root.join('public', 'javascripts', 'grid_widget'))
FileUtils.mkdir_p(css_dir = Rails.root.join('public', 'stylesheets', 'grid_widget'))

puts "Copying Javascript to " + js_dir.to_s

FileUtils.cp_r File.join(File.dirname(__FILE__), 'public', 'javascripts'), js_dir

puts "Copying Stylesheets and images to " + css_dir.to_s

FileUtils.cp_r File.join(File.dirname(__FILE__), 'public', 'stylesheets'), css_dir

puts "Files copied."
