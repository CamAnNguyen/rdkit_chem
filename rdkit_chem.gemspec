# frozen_string_literal: true

require_relative 'lib/rdkit_chem/version'

Gem::Specification.new do |s|
  s.name = 'rdkit_chem'
  s.version = RDKitChem::GEMVERSION
  s.authors = ['An Nguyen']
  s.email = ['caman.nguyenthanh@gmail.com']
  s.homepage = 'https://github.com/CamAnNguyen/rdkit-chem'
  s.summary = 'Ruby gem for RDKit'
  s.description = 'Ruby bindings for RDKit cheminformatics library'
  s.license = 'BSD-3-Clause'

  s.required_ruby_version = '>= 3.1.0'

  s.files = Dir[
    'lib/**/*.rb',
    'ext/**/*',
    'Code/**/*',
    'CMakeLists.txt',
    'Rakefile',
    'README.md',
    'LICENSE'
  ]

  # Platform-specific gems include pre-compiled binaries
  # Source gems use the extension for compilation
  ruby_version_dir = "#{RUBY_VERSION.split('.')[0..1].join('.')}.0"
  precompiled_dir = File.join(__dir__, 'lib', 'rdkit_chem', ruby_version_dir)

  if ENV['RDKIT_PRECOMPILED'] || File.directory?(precompiled_dir)
    # Pre-compiled binary gem - include the native libraries
    s.files += Dir["lib/rdkit_chem/#{ruby_version_dir}/**/*"]
    s.platform = Gem::Platform::CURRENT
  else
    # Source gem - requires compilation during install
    s.extensions = ['ext/rdkit_chem/extconf.rb']
  end

  s.require_paths = ['lib']

  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'test-unit', '~> 3.0'
end
