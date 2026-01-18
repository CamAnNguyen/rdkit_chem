# frozen_string_literal: true

require 'rdkit_chem/version'

# Try to load the native extension from multiple possible locations:
# 1. Pre-compiled gem: lib/rdkit_chem/<ruby_version>/RDKitChem.so
# 2. Source-compiled gem: rdkit_chem/lib/RDKitChem.so (legacy location)

def find_rdkit_native_extension
  ruby_version = "#{RUBY_VERSION.split('.')[0..1].join('.')}.0"

  # Location 1: Pre-compiled gem (platform-specific)
  precompiled_path = File.expand_path("rdkit_chem/#{ruby_version}", __dir__)
  return precompiled_path if File.directory?(precompiled_path)

  # Location 2: Source-compiled gem (legacy rdkit_chem/lib/)
  source_compiled_path = File.expand_path('../rdkit_chem/lib', __dir__)
  if File.exist?(File.join(source_compiled_path, 'RDKitChem.so')) ||
     File.exist?(File.join(source_compiled_path, 'RDKitChem.bundle'))
    return source_compiled_path
  end

  raise LoadError, 'Cannot find RDKitChem native extension. ' \
                   "Searched in:\n  - #{precompiled_path}\n  - #{source_compiled_path}"
end

def preload_rdkit_dylibs(native_path)
  return unless RUBY_PLATFORM.match?(/darwin/)

  bundle_path = File.join(native_path, 'RDKitChem.bundle')
  if File.exist?(bundle_path)
    bundle_size = File.size(bundle_path)
    return if bundle_size > 10_000_000
  end

  require 'fiddle'

  dylibs = Dir.glob(File.join(native_path, 'libRDKit*.dylib')).sort
  return if dylibs.empty?

  @rdkit_handles ||= []
  dylibs.each do |lib|
    @rdkit_handles << Fiddle::Handle.new(lib, Fiddle::RTLD_NOW | Fiddle::RTLD_GLOBAL)
  rescue ArgumentError
    @rdkit_handles << Fiddle::Handle.new(lib)
  end
end

native_path = find_rdkit_native_extension
$LOAD_PATH.unshift(native_path) unless $LOAD_PATH.include?(native_path)
preload_rdkit_dylibs(native_path)

require 'RDKitChem'
