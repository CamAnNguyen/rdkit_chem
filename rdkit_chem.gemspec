# frozen_string_literal: true

require_relative 'lib/rdkit_chem/version'

Gem::Specification.new do |s|
  s.name        = 'rdkit_chem'
  s.version     = RDKitChem::GEMVERSION
  s.authors     = ['An Nguyen']
  s.email       = ['caman.nguyenthanh@gmail.com']
  s.homepage    = 'https://github.com/CamAnNguyen/rdkit-chem'
  s.summary     = 'Ruby gem for RDKit'
  s.description = 'Ruby bindings for RDKit cheminformatics library'
  s.license     = 'BSD-3-Clause'

  s.required_ruby_version = '>= 2.7.0'

  s.files = Dir[
    'lib/**/*.rb',
    'ext/**/*',
    'Code/**/*',
    'CMakeLists.txt',
    'Rakefile',
    'README.md',
    'LICENSE'
  ]

  staged_dirs = Dir.glob(File.join(__dir__, 'lib', 'rdkit_chem', '*.0'))
                   .select { |d| File.directory?(d) }

  if ENV['RDKIT_PRECOMPILED'] || staged_dirs.any?
    staged_dirs.each do |dir|
      version_dir = File.basename(dir)
      s.files += Dir["lib/rdkit_chem/#{version_dir}/**/*"]
    end
    s.platform = Gem::Platform::CURRENT
  else
    s.extensions = ['ext/rdkit_chem/extconf.rb']
  end

  s.require_paths = ['lib']
  s.test_files    = Dir['test/**/*']

  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'test-unit', '~> 3.0'
end
