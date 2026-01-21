# frozen_string_literal: true

require 'rake/testtask'
require 'fileutils'
require 'set'

# Load additional tasks from tasks/ directory
Dir.glob('tasks/**/*.rake').each { |r| load r }

# Load version
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'rdkit_chem/version'

VERSION = RDKitChem::GEMVERSION
NATIVE_DIR = 'rdkit_chem/lib'

# System libraries that need to be bundled for portability
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

desc 'Build pre-compiled gem for current platform (x86_64-linux)'
task :build_native do
  # Check that native libraries exist
  unless File.exist?(File.join(NATIVE_DIR, 'RDKitChem.so'))
    abort "ERROR: Native extension not found at #{NATIVE_DIR}/RDKitChem.so\n" \
          "Run 'gem install rdkit_chem' first to compile, or build manually."
  end

  # Get Ruby version for directory structure
  ruby_version = "#{RUBY_VERSION.split('.')[0..1].join('.')}.0"
  target_dir = "lib/rdkit_chem/#{ruby_version}"

  puts "Packaging pre-compiled gem for Ruby #{ruby_version}..."

  # Create target directory
  FileUtils.mkdir_p(target_dir)

  # Copy native extension and all shared libraries
  Dir.glob("#{NATIVE_DIR}/*.so*").each do |lib|
    # Skip symlinks, copy only real files
    next if File.symlink?(lib)
    dest = File.join(target_dir, File.basename(lib))
    FileUtils.cp(lib, dest, verbose: true)
  end

  # Also copy symlinks (they're needed for library resolution)
  # This includes both .so -> .so.1 and .so.1 -> .so.1.version symlinks
  Dir.glob("#{NATIVE_DIR}/*.so*").each do |lib|
    next unless File.symlink?(lib)
    link_target = File.readlink(lib)
    dest = File.join(target_dir, File.basename(lib))
    FileUtils.rm_f(dest)
    FileUtils.ln_s(link_target, dest, verbose: true)
  end

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

desc 'Repair: bundle system libraries and fix RPATH'
task :repair do
  Rake::Task['bundle_system_libs'].invoke
  Rake::Task['fix_rpath'].invoke
end

MACOS_SYSTEM_LIBRARY_PREFIXES = ['/usr/lib/', '/System/'].freeze
MACOS_DEFAULT_SEARCH_PATHS = ['/opt/homebrew/lib', '/usr/local/lib'].freeze

def macos_shared_libraries(libs_dir)
  Dir.glob("#{libs_dir}/*.dylib") + Dir.glob("#{libs_dir}/*.bundle")
end

def macos_dependencies(lib)
  otool_output = `otool -L '#{lib}' 2>/dev/null`
  otool_output.lines.drop(1).map { |line| line.strip.split(' ').first }.compact
end

def macos_system_library?(path)
  MACOS_SYSTEM_LIBRARY_PREFIXES.any? { |prefix| path.start_with?(prefix) }
end

def macos_resolve_dependency(dep, libs_dir)
  return dep if dep.start_with?('/') && File.exist?(dep)

  basename = File.basename(dep)
  candidates = [File.join(libs_dir, basename)] +
               MACOS_DEFAULT_SEARCH_PATHS.map { |dir| File.join(dir, basename) }
  candidates.find { |path| File.exist?(path) }
end

desc 'Repair for macOS (bundle deps and fix install names)'
task :repair_macos do
  libs_dir = File.expand_path(NATIVE_DIR)
  libs = macos_shared_libraries(libs_dir)
  abort "ERROR: no macOS libraries found in #{libs_dir}" if libs.empty?

  queue = libs.dup
  processed = Set.new
  copied = 0

  until queue.empty?
    lib = queue.shift
    next if processed.include?(lib)
    processed.add(lib)

    macos_dependencies(lib).each do |dep|
      next if macos_system_library?(dep)

      dep_path = macos_resolve_dependency(dep, libs_dir)
      next if dep_path.nil?

      dest = File.join(libs_dir, File.basename(dep_path))
      unless File.exist?(dest)
        FileUtils.cp(dep_path, dest, verbose: true)
        copied += 1
      end
      queue << dest if File.exist?(dest)
    end
  end

  macos_shared_libraries(libs_dir).each do |lib|
    lib_name = File.basename(lib)
    system("install_name_tool -id @loader_path/#{lib_name} '#{lib}' 2>/dev/null") if lib.end_with?('.dylib')

    macos_dependencies(lib).each do |dep|
      next if macos_system_library?(dep)

      dep_basename = File.basename(dep)
      system("install_name_tool -change '#{dep}' '@loader_path/#{dep_basename}' '#{lib}' 2>/dev/null")
    end
  end

  puts "Bundled #{copied} macOS dependencies."
end

desc 'Test that native extension loads without LD_LIBRARY_PATH'
task :test_native do
  so_dir = File.expand_path(NATIVE_DIR, __dir__)
  puts "Testing native extension loading from #{so_dir}..."

  # Test without LD_LIBRARY_PATH
  result = system("ruby -I#{so_dir} -Ilib -e \"require 'rdkit_chem'; puts 'SUCCESS: RDKitChem loaded'\"")

  if result
    puts "\nNative extension loads correctly without LD_LIBRARY_PATH!"
  else
    puts "\nFAILED: Still requires LD_LIBRARY_PATH. Run 'rake fix_rpath' first."
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
end

task default: :test
