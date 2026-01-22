# frozen_string_literal: true

require 'rdkit_chem/version'

# Try to load the native extension from multiple possible locations:
# 1. Pre-compiled gem: lib/rdkit_chem/<ruby_version>/RDKitChem.so (fat gem with all Ruby versions)
# 2. Source-compiled gem: rdkit_chem/lib/RDKitChem.so (development/legacy location)

def find_rdkit_native_extension
  ruby_version = "#{RUBY_VERSION.split('.')[0..1].join('.')}.0"
  base_dir = File.expand_path('rdkit_chem', __dir__)

  # Location 1: Pre-compiled gem - exact Ruby version match (fat gem)
  precompiled_path = File.join(base_dir, ruby_version)
  return precompiled_path if File.directory?(precompiled_path) && has_native_extension?(precompiled_path)

  # Location 2: Source-compiled gem (development build at rdkit_chem/lib/)
  source_compiled_path = File.expand_path('../rdkit_chem/lib', __dir__)
  return source_compiled_path if has_native_extension?(source_compiled_path)

  # List available Ruby versions for better error message
  available_versions = Dir.glob(File.join(base_dir, '*.0'))
                          .select { |d| has_native_extension?(d) }
                          .map { |d| File.basename(d) }

  error_msg = "Cannot find RDKitChem native extension for Ruby #{ruby_version}.\n"
  error_msg += "Searched in:\n  - #{precompiled_path}\n  - #{source_compiled_path}\n"
  if available_versions.any?
    error_msg += "Available versions in gem: #{available_versions.join(', ')}\n"
    error_msg += 'You may need to install a newer version of rdkit_chem gem.'
  end

  raise LoadError, error_msg
end

def has_native_extension?(dir)
  File.exist?(File.join(dir, 'RDKitChem.so')) ||
    File.exist?(File.join(dir, 'RDKitChem.bundle'))
end

native_path = find_rdkit_native_extension
$LOAD_PATH.unshift(native_path) unless $LOAD_PATH.include?(native_path)

require 'RDKitChem'
