# frozen_string_literal: true

require 'rake/testtask'
require 'fileutils'
require 'set'

# Load version
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'rdkit_chem/version'

VERSION = RDKitChem::GEMVERSION
NATIVE_DIR = 'rdkit_chem/lib'

# System libraries that are safe to depend on (present on all Linux systems)
# These should NOT be bundled - they're part of the base system
SYSTEM_LIBS_ALLOWLIST = [
  /^libc\.so/,
  /^libm\.so/,
  /^libpthread\.so/,
  /^libdl\.so/,
  /^librt\.so/,
  /^libstdc\+\+\.so/,
  /^libgcc_s\.so/,
  /^linux-vdso\.so/,
  /^ld-linux/,
  /^libresolv\.so/,
  /^libnsl\.so/,
  /^libcrypt\.so/,
  /^libutil\.so/,
].freeze

# Legacy constant for backward compatibility
BUNDLED_SYSTEM_LIBS = %w[
  libboost_serialization.so*
  libboost_iostreams.so*
].freeze

desc 'Run tests'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb,test/**/test_*.rb'
  t.verbose = true
end

desc 'Build source gem (requires compilation on install)'
task :build do
  sh 'gem build rdkit_chem.gemspec'
end

desc 'Build pre-compiled gem for current platform'
task :build_native do
  # Check that native libraries exist (different extensions per platform)
  extension_file = if RUBY_PLATFORM =~ /darwin/
                     File.join(NATIVE_DIR, 'RDKitChem.bundle')
                   else
                     File.join(NATIVE_DIR, 'RDKitChem.so')
                   end
  
  unless File.exist?(extension_file)
    abort "ERROR: Native extension not found at #{extension_file}\n" \
          "Run 'gem install rdkit_chem' first to compile, or build manually."
  end

  # Get Ruby version for directory structure
  ruby_version = "#{RUBY_VERSION.split('.')[0..1].join('.')}.0"
  target_dir = "lib/rdkit_chem/#{ruby_version}"

  puts "Packaging pre-compiled gem for Ruby #{ruby_version}..."

  # Create target directory
  FileUtils.mkdir_p(target_dir)

  # Copy all shared libraries - resolve symlinks to actual files for cross-platform compatibility
  # RubyGems warns about symlinks not being supported on all platforms (especially Windows)
  # Pattern matches: .so* (Linux), .dylib (macOS), .bundle (macOS Ruby extension)
  copied_files = Set.new
  lib_patterns = ["#{NATIVE_DIR}/*.so*", "#{NATIVE_DIR}/*.dylib", "#{NATIVE_DIR}/*.bundle"]
  
  lib_patterns.flat_map { |p| Dir.glob(p) }.uniq.each do |lib|
    next if lib.end_with?('.a') # Skip static libraries
    
    # Get the real file (resolving symlinks)
    real_file = File.realpath(lib)
    basename = File.basename(lib)
    dest = File.join(target_dir, basename)
    
    # If this is a symlink, copy the actual file with the symlink's name
    # This flattens the symlink structure: libFoo.so.1 -> libFoo.so.1.2026... becomes just libFoo.so.1
    if File.symlink?(lib)
      # Copy actual content to the symlink name (avoiding duplicates)
      unless copied_files.include?(dest)
        FileUtils.cp(real_file, dest, verbose: true)
        copied_files.add(dest)
      end
    else
      # Regular file - copy directly
      unless copied_files.include?(dest)
        FileUtils.cp(lib, dest, verbose: true)
        copied_files.add(dest)
      end
    end
  end

  puts "Copied #{copied_files.size} library files (symlinks resolved to actual files)"

  # Build the platform-specific gem
  ENV['RDKIT_PRECOMPILED'] = '1'
  sh 'gem build rdkit_chem.gemspec'
  ENV.delete('RDKIT_PRECOMPILED')

  # Clean up
  FileUtils.rm_rf(target_dir)

  puts "\nBuilt: rdkit_chem-#{VERSION}-#{Gem::Platform.local}.gem"
end

desc 'Bundle system libraries (Boost) into native directory'
task :bundle_system_libs do
  so_file = File.join(NATIVE_DIR, 'RDKitChem.so')
  unless File.exist?(so_file)
    abort "ERROR: #{so_file} not found"
  end

  puts "Finding and bundling system library dependencies..."

  # Find library paths using ldd
  ldd_output = `ldd #{so_file} 2>/dev/null`

  BUNDLED_SYSTEM_LIBS.each do |lib_pattern|
    lib_name = lib_pattern.gsub('*', '')
    # Extract actual library path from ldd output
    match = ldd_output.match(/#{Regexp.escape(lib_name)}[^\s]* => ([^\s]+)/)
    if match
      src_path = match[1]
      if File.exist?(src_path)
        dest = File.join(NATIVE_DIR, File.basename(src_path))
        unless File.exist?(dest)
          FileUtils.cp(src_path, dest, verbose: true)
        else
          puts "Already exists: #{dest}"
        end
      end
    else
      puts "WARNING: Could not find #{lib_pattern} in ldd output"
    end
  end

  puts "Done bundling system libraries."
end

desc 'Apply RPATH fix to existing native extension (no recompile needed)'
task :fix_rpath do
  so_file = File.join(NATIVE_DIR, 'RDKitChem.so')
  unless File.exist?(so_file)
    abort "ERROR: #{so_file} not found"
  end

  # Check if patchelf is available
  unless system('which patchelf > /dev/null 2>&1')
    abort "ERROR: patchelf not installed. Run: sudo apt install patchelf"
  end

  # Fix RPATH on all shared libraries (including versioned ones like *.so.1.2026.03.1pre)
  puts "Setting RPATH to $ORIGIN on all shared libraries..."
  count = 0
  Dir.glob("#{NATIVE_DIR}/*.so*").each do |lib|
    next if File.symlink?(lib)  # Skip symlinks
    next if lib.end_with?('.a') # Skip static libraries
    system("patchelf --set-rpath '$ORIGIN' '#{lib}' 2>/dev/null")
    count += 1
  end
  puts "Fixed RPATH on #{count} libraries"

  # Verify main extension
  puts "\nVerifying RPATH on #{so_file}:"
  sh "readelf -d #{so_file} | grep -E '(RPATH|RUNPATH)' || echo 'No RPATH found'"
end

desc 'Test that native extension loads without LD_LIBRARY_PATH'
task :test_native do
  so_dir = File.expand_path(NATIVE_DIR, __dir__)
  puts "Testing native extension loading from #{so_dir}..."

  # Test without LD_LIBRARY_PATH / DYLD_LIBRARY_PATH
  # Clear environment to ensure we're not relying on system paths
  env = { 'LD_LIBRARY_PATH' => '', 'DYLD_LIBRARY_PATH' => '' }
  cmd = "ruby -I#{so_dir} -Ilib -e \"require 'rdkit_chem'; puts 'SUCCESS: RDKitChem loaded'\""

  # Use spawn to ensure clean environment
  result = system(env, cmd)

  if result
    puts "\nNative extension loads correctly without library path environment variables!"
  else
    puts "\nFAILED: Extension failed to load."
    if RUBY_PLATFORM =~ /darwin/
      puts "Run 'rake repair_macos' to fix library paths."
    else
      puts "Run 'rake repair' or 'rake fix_rpath' to fix RPATH."
    end
    exit 1
  end
end

desc 'Install gem locally'
task :install => :build do
  sh "gem install rdkit_chem-#{VERSION}.gem"
end

desc 'Clean build artifacts'
task :clean do
  FileUtils.rm_f(Dir.glob('*.gem'))
  FileUtils.rm_rf('lib/rdkit_chem/3.0')
  FileUtils.rm_rf('lib/rdkit_chem/3.1')
  FileUtils.rm_rf('lib/rdkit_chem/3.2')
  FileUtils.rm_rf('lib/rdkit_chem/3.3')
  FileUtils.rm_rf('lib/rdkit_chem/3.4')
  FileUtils.rm_rf('lib/rdkit_chem/4.0')
end

# =============================================================================
# REPAIR TASK - Ruby's equivalent of Python's auditwheel
# =============================================================================
# This task bundles all external dependencies into the native directory and
# fixes RPATH so the gem is completely self-contained (zero runtime dependencies)
# =============================================================================

desc 'Repair: bundle all dependencies and fix RPATH (like auditwheel)'
task :repair do
  so_file = File.join(NATIVE_DIR, 'RDKitChem.so')
  unless File.exist?(so_file)
    abort "ERROR: #{so_file} not found. Build the extension first."
  end

  unless system('which patchelf > /dev/null 2>&1')
    abort "ERROR: patchelf not installed. Run: sudo apt install patchelf"
  end

  puts "=" * 70
  puts "REPAIR: Bundling dependencies (Ruby's auditwheel equivalent)"
  puts "=" * 70

  # Step 1: Find all external dependencies recursively
  puts "\n[Step 1/4] Scanning dependencies..."
  external_deps = find_external_dependencies(NATIVE_DIR)
  
  if external_deps.empty?
    puts "  No external dependencies to bundle."
  else
    puts "  Found #{external_deps.size} external dependencies to bundle:"
    external_deps.each { |dep| puts "    - #{dep}" }
  end

  # Step 2: Copy external dependencies into NATIVE_DIR
  puts "\n[Step 2/4] Bundling external libraries..."
  bundled_count = 0
  external_deps.each do |lib_path|
    dest = File.join(NATIVE_DIR, File.basename(lib_path))
    unless File.exist?(dest)
      FileUtils.cp(lib_path, dest, verbose: true)
      bundled_count += 1
      
      # Also copy symlinks if they exist
      copy_library_symlinks(lib_path, NATIVE_DIR)
    end
  end
  puts "  Bundled #{bundled_count} new libraries."

  # Step 3: Fix RPATH on ALL .so files
  puts "\n[Step 3/4] Fixing RPATH on all shared libraries..."
  rpath_count = 0
  Dir.glob("#{NATIVE_DIR}/*.so*").each do |lib|
    next if File.symlink?(lib)
    next if lib.end_with?('.a')
    
    # Set RPATH to $ORIGIN so libraries find each other
    result = system("patchelf --set-rpath '$ORIGIN' '#{lib}' 2>/dev/null")
    rpath_count += 1 if result
  end
  puts "  Fixed RPATH on #{rpath_count} libraries."

  # Step 4: Verify self-contained
  puts "\n[Step 4/4] Verifying all dependencies are bundled..."
  verify_self_contained(NATIVE_DIR)

  puts "\n" + "=" * 70
  puts "REPAIR COMPLETE"
  puts "=" * 70
end

desc 'Show external dependencies that would be bundled'
task :repair_dry_run do
  so_file = File.join(NATIVE_DIR, 'RDKitChem.so')
  unless File.exist?(so_file)
    abort "ERROR: #{so_file} not found."
  end

  puts "External dependencies that would be bundled:\n\n"
  
  external_deps = find_external_dependencies(NATIVE_DIR)
  
  if external_deps.empty?
    puts "  (none - all dependencies already bundled or system libs)"
  else
    external_deps.each do |dep|
      size = File.size(dep) / 1024.0 / 1024.0
      puts "  #{File.basename(dep).ljust(40)} #{format('%.2f MB', size).rjust(10)}  <- #{dep}"
    end
    
    total_size = external_deps.sum { |dep| File.size(dep) } / 1024.0 / 1024.0
    puts "\n  Total: #{external_deps.size} libraries, #{format('%.2f MB', total_size)}"
  end
end

desc 'Verify gem is self-contained (no external dependencies)'
task :verify_self_contained do
  verify_self_contained(NATIVE_DIR)
end

# macOS system frameworks/libraries that should NOT be bundled
MACOS_SYSTEM_LIBS = [
  %r{^/usr/lib/},
  %r{^/System/},
  %r{^@rpath/libruby},  # Ruby library - resolved at runtime
  %r{libruby},          # Ruby library
].freeze

desc 'Repair for macOS (install_name_tool)'
task :repair_macos do
  libs_dir = File.expand_path(NATIVE_DIR)
  bundle_file = File.join(libs_dir, 'RDKitChem.bundle')

  unless File.exist?(bundle_file)
    abort "ERROR: #{bundle_file} not found. Build the extension first."
  end

  puts "=" * 70
  puts "REPAIR macOS: Bundling dependencies and fixing library paths"
  puts "=" * 70

  # Step 1: Find and bundle external dependencies (recursively)
  puts "\n[Step 1/5] Finding and bundling external dependencies..."
  total_bundled = 0
  iteration = 0
  max_iterations = 10  # Safety limit

  loop do
    iteration += 1
    external_deps = find_macos_external_dependencies(libs_dir)

    if external_deps.empty?
      puts "  Iteration #{iteration}: No more external dependencies to bundle."
      break
    end

    if iteration > max_iterations
      puts "  WARNING: Reached max iterations (#{max_iterations}), stopping."
      break
    end

    puts "  Iteration #{iteration}: Found #{external_deps.size} dependencies to bundle:"
    external_deps.each { |dep| puts "    - #{dep}" }

    external_deps.each do |lib_path|
      dest = File.join(libs_dir, File.basename(lib_path))
      unless File.exist?(dest)
        FileUtils.cp(lib_path, dest, verbose: true)
        total_bundled += 1
      end
    end
  end

  puts "  Bundled #{total_bundled} total libraries."

  # Rescan after bundling
  all_libs = Dir.glob("#{libs_dir}/*.dylib") + Dir.glob("#{libs_dir}/*.bundle")

  puts "\n[Step 2/5] Setting install names and rpath..."
  all_libs.each do |lib|
    next if File.symlink?(lib)
    lib_name = File.basename(lib)
    system("install_name_tool -id @loader_path/#{lib_name} '#{lib}' 2>/dev/null")
    system("install_name_tool -add_rpath @loader_path '#{lib}' 2>/dev/null")
  end

  puts "\n[Step 3/5] Rewriting dependency paths to @loader_path..."
  rewrite_count = 0
  all_libs.each do |lib|
    next if File.symlink?(lib)

    otool_output = `otool -L '#{lib}' 2>/dev/null`
    otool_output.each_line do |line|
      next unless line.include?('.dylib') || line.include?('.bundle')

      dep_path = line.strip.split(' ').first
      next if dep_path.nil? || dep_path.empty?
      next if dep_path.start_with?('/usr/lib/', '/System/')
      next if dep_path.start_with?('@loader_path/')

      dep_name = File.basename(dep_path)

      if dep_path.start_with?('@rpath/') || !dep_path.start_with?('@')
        system("install_name_tool -change '#{dep_path}' '@loader_path/#{dep_name}' '#{lib}' 2>/dev/null")
        rewrite_count += 1
      end
    end
  end

  puts "  Rewrote #{rewrite_count} dependency paths"

  # Step 4: Re-sign all libraries (required for Apple Silicon)
  # Modifying binaries with install_name_tool invalidates code signatures
  puts "\n[Step 4/5] Re-signing libraries for Apple Silicon..."
  sign_count = 0
  all_libs.each do |lib|
    next if File.symlink?(lib)
    # Ad-hoc sign with force to replace any existing signature
    result = system("codesign --force --sign - '#{lib}' 2>/dev/null")
    sign_count += 1 if result
  end
  puts "  Signed #{sign_count} libraries"

  # Verification step
  puts "\n[Step 5/5] Verifying all dependencies are bundled..."
  verify_macos_self_contained(libs_dir)

  puts "\n" + "=" * 70
  puts "macOS library repair complete!"
  puts "=" * 70
end

# Find external dependencies for macOS libraries using otool
def find_macos_external_dependencies(libs_dir)
  external_deps = Set.new

  all_libs = Dir.glob("#{libs_dir}/*.dylib") + Dir.glob("#{libs_dir}/*.bundle")

  all_libs.each do |lib|
    next if File.symlink?(lib)
    next unless File.file?(lib)

    otool_output = `otool -L '#{lib}' 2>/dev/null`

    otool_output.each_line do |line|
      next unless line.include?('.dylib')

      dep_path = line.strip.split(' ').first
      next if dep_path.nil? || dep_path.empty?

      # Skip system libraries
      next if MACOS_SYSTEM_LIBS.any? { |pattern| dep_path.match?(pattern) }

      # Skip already-rewritten paths
      next if dep_path.start_with?('@loader_path/', '@executable_path/')

      # Handle @rpath references - try to resolve them
      if dep_path.start_with?('@rpath/')
        dep_name = File.basename(dep_path)
        # Skip if already bundled
        next if File.exist?(File.join(libs_dir, dep_name))

        # Try to find in common locations
        resolved = find_macos_library(dep_name)
        external_deps.add(resolved) if resolved
      elsif File.exist?(dep_path)
        # Absolute path - skip if already bundled
        next if File.exist?(File.join(libs_dir, File.basename(dep_path)))
        external_deps.add(dep_path)
      end
    end
  end

  external_deps.to_a.sort
end

# Find a macOS library by name in common locations
def find_macos_library(lib_name)
  search_paths = [
    '/opt/homebrew/lib',           # Homebrew ARM64
    '/usr/local/lib',              # Homebrew x86_64
    '/opt/local/lib',              # MacPorts
    ENV['LIBRARY_PATH'],           # Custom paths
  ].compact.reject(&:empty?)

  search_paths.each do |path|
    full_path = File.join(path, lib_name)
    return full_path if File.exist?(full_path)

    # Try versioned variants
    Dir.glob("#{path}/#{lib_name}*").each do |variant|
      return variant if File.file?(variant) && !File.symlink?(variant)
    end
  end

  nil
end

# Verify macOS gem is self-contained
def verify_macos_self_contained(libs_dir)
  bundle_file = File.join(libs_dir, 'RDKitChem.bundle')
  missing = []

  all_libs = Dir.glob("#{libs_dir}/*.dylib") + Dir.glob("#{libs_dir}/*.bundle")

  all_libs.each do |lib|
    next if File.symlink?(lib)

    otool_output = `otool -L '#{lib}' 2>/dev/null`

    otool_output.each_line do |line|
      next unless line.include?('.dylib') || line.include?('.bundle')

      dep_path = line.strip.split(' ').first
      next if dep_path.nil? || dep_path.empty?

      # System libraries are OK
      next if dep_path.start_with?('/usr/lib/', '/System/')

      # @loader_path references - check if the file exists
      if dep_path.start_with?('@loader_path/')
        dep_name = dep_path.sub('@loader_path/', '')
        unless File.exist?(File.join(libs_dir, dep_name))
          missing << "#{File.basename(lib)} -> #{dep_path} (file not found)"
        end
      elsif dep_path.start_with?('@rpath/')
        # @rpath should have been rewritten to @loader_path
        missing << "#{File.basename(lib)} -> #{dep_path} (should be @loader_path)"
      elsif !dep_path.start_with?('@')
        # Absolute paths that aren't system libraries
        next if dep_path.include?('libruby')  # Ruby library is OK
        missing << "#{File.basename(lib)} -> #{dep_path} (absolute path)"
      end
    end
  end

  if missing.empty?
    puts "  ✓ All dependencies resolved!"
  else
    puts "  ⚠ Warning: Some dependencies may not be bundled:"
    missing.uniq.first(10).each { |m| puts "    - #{m}" }
    puts "    ... and #{missing.size - 10} more" if missing.size > 10
  end
end

desc 'Repair for Windows (copy DLLs)'
task :repair_windows do
  puts "Repairing Windows libraries..."
  
  dll_search_paths = [
    ENV.fetch('VCPKG_ROOT', 'C:/vcpkg') + '/installed/x64-windows/bin',
    'C:/boost/lib',
    'C:/Windows/System32',
  ].select { |p| File.directory?(p) }
  
  dll_file = File.join(NATIVE_DIR, 'RDKitChem.dll')
  unless File.exist?(dll_file)
    puts "No RDKitChem.dll found, skipping Windows repair"
    return
  end
  
  dumpbin_output = `dumpbin /dependents "#{dll_file}" 2>/dev/null` rescue ''
  
  dumpbin_output.scan(/^\s+(\S+\.dll)/i).flatten.each do |dll|
    next if dll.downcase.start_with?('kernel32', 'user32', 'msvcrt', 'ntdll', 'advapi32')
    
    dll_search_paths.each do |search_path|
      src = File.join(search_path, dll)
      if File.exist?(src)
        dest = File.join(NATIVE_DIR, dll)
        unless File.exist?(dest)
          FileUtils.cp(src, dest, verbose: true)
        end
        break
      end
    end
  end
  
  puts "Windows library repair complete!"
end

# =============================================================================
# Helper methods for repair task
# =============================================================================

def find_external_dependencies(libs_dir)
  external_deps = Set.new
  
  # Scan all .so files in the directory
  Dir.glob("#{libs_dir}/*.so*").each do |lib|
    next if File.symlink?(lib)
    next unless File.file?(lib)
    
    # Use ldd to find dependencies
    ldd_output = `ldd '#{lib}' 2>/dev/null`
    
    ldd_output.each_line do |line|
      # Parse: libname.so.1 => /path/to/libname.so.1 (0x...)
      if line =~ /^\s*(\S+)\s+=>\s+(\S+)\s+\(/
        lib_name = $1
        lib_path = $2
        
        next if lib_path == 'not' # "not found" case
        next unless File.exist?(lib_path)
        
        # Skip system libraries
        next if system_library?(lib_name)
        
        # Skip if already in our libs_dir
        next if File.exist?(File.join(libs_dir, File.basename(lib_path)))
        
        external_deps.add(lib_path)
      end
    end
  end
  
  external_deps.to_a.sort
end

def system_library?(lib_name)
  SYSTEM_LIBS_ALLOWLIST.any? { |pattern| lib_name.match?(pattern) }
end

def copy_library_symlinks(lib_path, dest_dir)
  lib_dir = File.dirname(lib_path)
  lib_basename = File.basename(lib_path)
  
  # Find symlinks pointing to this library
  Dir.glob("#{lib_dir}/*.so*").each do |potential_link|
    next unless File.symlink?(potential_link)
    
    link_target = File.readlink(potential_link)
    link_target_basename = File.basename(link_target)
    
    # Check if this symlink points to our library (directly or indirectly)
    if link_target_basename == lib_basename || link_target == lib_basename
      dest_link = File.join(dest_dir, File.basename(potential_link))
      unless File.exist?(dest_link)
        # Create relative symlink
        FileUtils.ln_s(link_target_basename, dest_link, verbose: true)
      end
    end
  end
end

def verify_self_contained(libs_dir)
  so_file = File.join(libs_dir, 'RDKitChem.so')
  
  puts "Checking #{so_file} for unresolved dependencies..."
  
  # Set LD_LIBRARY_PATH to the libs_dir and check for "not found"
  env = { 'LD_LIBRARY_PATH' => File.expand_path(libs_dir) }
  ldd_output = `#{env.map { |k, v| "#{k}=#{v}" }.join(' ')} ldd '#{so_file}' 2>&1`
  
  # Filter out "not found" lines, EXCLUDING libruby which is intentionally not bundled
  # Ruby extensions resolve libruby symbols at runtime when loaded into Ruby process
  not_found = ldd_output.lines.select do |line|
    line.include?('not found') && !line.include?('libruby')
  end
  
  if not_found.empty?
    puts "  ✓ All dependencies resolved!"
    
    # Also check for external (non-bundled) dependencies
    external = find_external_dependencies(libs_dir)
    if external.empty?
      puts "  ✓ All non-system dependencies are bundled!"
    else
      puts "  ⚠ Warning: #{external.size} external dependencies not yet bundled:"
      external.each { |dep| puts "    - #{dep}" }
      return false
    end
    
    true
  else
    puts "  ✗ ERROR: Unresolved dependencies:"
    not_found.each { |line| puts "    #{line.strip}" }
    abort "Repair incomplete - some dependencies missing!"
  end
end

task default: :test