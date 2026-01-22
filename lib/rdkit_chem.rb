# frozen_string_literal: true

require 'rdkit_chem/version'

# Try to load the native extension from multiple possible locations:
# 1. Pre-compiled gem: lib/rdkit_chem/<ruby_version>/RDKitChem.so
# 2. Source-compiled gem: rdkit_chem/lib/RDKitChem.so (legacy location)

def find_rdkit_native_extension
  ruby_version = "#{RUBY_VERSION.split('.')[0..1].join('.')}.0"
  base_dir = File.expand_path('rdkit_chem', __dir__)

  # Location 1: Pre-compiled gem - exact Ruby version match
  precompiled_path = File.join(base_dir, ruby_version)
  return precompiled_path if File.directory?(precompiled_path) && has_native_extension?(precompiled_path)

  # Location 2: Pre-compiled gem - any available Ruby version (fallback)
  # This handles cases where gem was built with different Ruby minor version
  if File.directory?(base_dir)
    Dir.glob(File.join(base_dir, '*.0')).sort.reverse.each do |version_dir|
      return version_dir if has_native_extension?(version_dir)
    end
  end

  # Location 3: Source-compiled gem (legacy rdkit_chem/lib/)
  source_compiled_path = File.expand_path('../rdkit_chem/lib', __dir__)
  return source_compiled_path if has_native_extension?(source_compiled_path)

  raise LoadError, 'Cannot find RDKitChem native extension. ' \
                   "Searched in:\n  - #{precompiled_path}\n  - #{base_dir}/*.0\n  - #{source_compiled_path}"
end

def has_native_extension?(dir)
  File.exist?(File.join(dir, 'RDKitChem.so')) ||
    File.exist?(File.join(dir, 'RDKitChem.bundle'))
end

native_path = find_rdkit_native_extension
$LOAD_PATH.unshift(native_path) unless $LOAD_PATH.include?(native_path)

require 'RDKitChem'
