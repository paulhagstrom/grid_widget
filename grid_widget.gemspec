# coding: utf-8
# this was generated with Rails 4.2.9 and might have stuff in it that needs Rails 4
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "grid_widget/version"

Gem::Specification.new do |spec|
  spec.name          = "grid_widget"
  spec.version       = GridWidget::VERSION
  spec.authors       = ["Paul Hagstrom"]
  spec.email         = ["hagstrom@bu.edu"]

  spec.summary       = %q{GridWidget, apotomo, Rails, jqgrid}
  spec.description   = %q{GridWidget, apotomo, Rails, jqgrid. In a gem.}
  spec.homepage      = "http://example.com"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata["allowed_push_host"] = "http://example.com"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against " \
  #     "public gem pushes."
  # end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
