# frozen_string_literal: true

require 'rdkit_chem/version'

# Try to load the native extension from multiple possible locations:
# 1. Pre-compiled gem: lib/rdkit_chem/<ruby_version>/RDKitChem.so
# 2. Source-compiled gem: rdkit_chem/lib/RDKitChem.so (legacy location)

def find_rdkit_native_extension
  ruby_version = "#{RUBY_VERSION.split('.')[0..1].join('.')}.0"

  # Location 1: Pre-compiled gem (platform-specific)
  precompiled_path = File.expand_path("rdkit_chem/#{ruby_version}", __dir__)
  if File.directory?(precompiled_path)
    return precompiled_path
  end

  # Location 2: Source-compiled gem (legacy rdkit_chem/lib/)
  source_compiled_path = File.expand_path('../rdkit_chem/lib', __dir__)
  if File.exist?(File.join(source_compiled_path, 'RDKitChem.so')) ||
     File.exist?(File.join(source_compiled_path, 'RDKitChem.bundle'))
    return source_compiled_path
  end

  raise LoadError, "Cannot find RDKitChem native extension. " \
                   "Searched in:\n  - #{precompiled_path}\n  - #{source_compiled_path}"
end

def preload_rdkit_dylibs(native_path)
  # On macOS, the bundle is built with RDK_SWIG_STATIC=ON, meaning all RDKit
  # symbols are statically linked. Preloading dylibs would cause symbol conflicts.
  # On Linux, we don't need to preload either as RPATH handles library resolution.
  # This function is kept as a no-op for backward compatibility.
end

native_path = find_rdkit_native_extension
$LOAD_PATH.unshift(native_path) unless $LOAD_PATH.include?(native_path)
preload_rdkit_dylibs(native_path)

require 'RDKitChem'
