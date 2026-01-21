# frozen_string_literal: true

# SWIG wrapper generation tasks for rdkit_chem
#
# Usage:
#   rake swig:generate  # Generate wrapper (requires SWIG + RDKit headers)
#   rake swig:patch     # Apply Ruby 3.2+ compatibility patches
#   rake swig:build     # Generate and patch in one step
#   rake swig:clean     # Remove generated wrapper
#   rake swig:status    # Check wrapper status
#
# Environment variables:
#   RDKIT_INCLUDE_DIR  - Path to RDKit headers (e.g., /usr/local/include/rdkit)
#   BOOST_INCLUDE_DIR  - Path to Boost headers (e.g., /usr/local/include)
#   SWIG_EXECUTABLE    - Path to SWIG binary (default: swig)

require 'fileutils'
require 'rbconfig'

namespace :swig do
  # Paths relative to project root
  RUBY_WRAPPERS_DIR = 'Code/RubyWrappers'
  GMWRAPPER_DIR = "#{RUBY_WRAPPERS_DIR}/gmwrapper"
  INTERFACE_FILE = "#{GMWRAPPER_DIR}/GraphMolRuby.i"
  WRAPPER_FILE = "#{GMWRAPPER_DIR}/GraphMolRuby_wrap.cxx"
  WRAPPER_HEADER = "#{GMWRAPPER_DIR}/GraphMolRuby_wrap.h"

  # Detect platform
  def macos?
    RbConfig::CONFIG['host_os'] =~ /darwin/
  end

  def linux?
    RbConfig::CONFIG['host_os'] =~ /linux/
  end

  # Find SWIG executable
  def swig_executable
    ENV['SWIG_EXECUTABLE'] || find_executable('swig')
  end

  def find_executable(name)
    paths = ENV['PATH'].split(File::PATH_SEPARATOR)
    paths.each do |path|
      exe = File.join(path, name)
      return exe if File.executable?(exe)
    end
    name # Fall back to just the name
  end

  # Detect RDKit include directory
  # Returns the primary RDKit include directory (either source or installed headers)
  def rdkit_include_dir
    return ENV['RDKIT_INCLUDE_DIR'] if ENV['RDKIT_INCLUDE_DIR']

    project_root = File.expand_path('..', __dir__)

    # Common locations (in priority order)
    candidates = [
      File.join(project_root, 'rdkit_chem/include/rdkit'),  # Installed headers from build
      File.join(project_root, 'rdkit/Code'),                # Local RDKit source
      '/usr/local/include/rdkit',                           # Homebrew Intel
      '/opt/homebrew/include/rdkit',                        # Homebrew ARM
      '/usr/include/rdkit' # Linux system
    ]

    candidates.find { |dir| File.directory?(dir) }
  end

  # Get all RDKit include directories (may include multiple paths)
  # This is needed because some headers reference relative paths like ../RDGeneral/
  def rdkit_include_dirs
    dirs = []
    project_root = File.expand_path('..', __dir__)

    # If RDKIT_INCLUDE_DIR is set, use it as primary
    if ENV['RDKIT_INCLUDE_DIR']
      dirs << ENV['RDKIT_INCLUDE_DIR']
      # Also add parent for relative includes like ../RDGeneral/
      parent = File.dirname(ENV['RDKIT_INCLUDE_DIR'])
      dirs << parent if File.directory?(parent)
    end

    # Always include installed headers if available (has generated files like export.h)
    installed = File.join(project_root, 'rdkit_chem/include/rdkit')
    dirs << installed if File.directory?(installed)

    # Include the parent of installed for relative paths
    installed_parent = File.join(project_root, 'rdkit_chem/include')
    dirs << installed_parent if File.directory?(installed_parent)

    # Include Code directory for RubyWrappers/GenericRDKitException.h
    code_dir = File.join(project_root, 'Code')
    dirs << code_dir if File.directory?(code_dir)

    # Also include RubyWrappers directory directly
    ruby_wrappers = File.join(project_root, 'Code/RubyWrappers')
    dirs << ruby_wrappers if File.directory?(ruby_wrappers)

    dirs.uniq
  end

  # Detect Boost include directory
  def boost_include_dir
    return ENV['BOOST_INCLUDE_DIR'] if ENV['BOOST_INCLUDE_DIR']

    candidates = [
      '/usr/local/include',                 # Homebrew Intel
      '/opt/homebrew/include',              # Homebrew ARM
      '/usr/include' # Linux system
    ]

    # Look for boost directory
    candidates.find { |dir| File.directory?(File.join(dir, 'boost')) }
  end

  # Get Ruby include paths
  def ruby_include_paths
    [
      RbConfig::CONFIG['rubyhdrdir'],
      RbConfig::CONFIG['rubyarchhdrdir'] || File.join(RbConfig::CONFIG['rubyhdrdir'], RbConfig::CONFIG['arch'])
    ].compact.uniq
  end

  # Build feature flags based on environment
  def feature_flags
    flags = []

    # These can be enabled via environment or detected
    flags << '-DRDK_BUILD_INCHI_SUPPORT' if ENV['RDK_BUILD_INCHI_SUPPORT'] == '1'
    flags << '-DRDK_BUILD_AVALON_SUPPORT' if ENV['RDK_BUILD_AVALON_SUPPORT'] == '1'
    flags << '-DRDK_USE_BOOST_IOSTREAMS' if ENV['RDK_USE_BOOST_IOSTREAMS'] == '1'

    flags
  end

  desc 'Check SWIG generation prerequisites'
  task :check do
    errors = []

    # Check SWIG
    swig = swig_executable
    if system("#{swig} -version > /dev/null 2>&1")
      version = begin
        `#{swig} -version 2>&1`.match(/SWIG Version (\d+\.\d+)/)[1]
      rescue StandardError
        nil
      end
      errors << "SWIG version 4.0+ required, found #{version}" if version && version.to_f < 4.0
    else
      errors << 'SWIG not found. Install with: brew install swig (macOS) or apt install swig (Linux)'
    end

    # Check RDKit headers
    rdkit_dir = rdkit_include_dir
    if rdkit_dir.nil? || !File.directory?(rdkit_dir)
      errors << 'RDKit headers not found. Set RDKIT_INCLUDE_DIR or install RDKit'
    end

    # Check Boost headers
    boost_dir = boost_include_dir
    errors << 'Boost headers not found. Set BOOST_INCLUDE_DIR or install Boost' if boost_dir.nil?

    # Check interface file
    errors << "Interface file not found: #{INTERFACE_FILE}" unless File.exist?(INTERFACE_FILE)

    if errors.any?
      puts 'Prerequisites check failed:'
      errors.each { |e| puts "  - #{e}" }
      exit 1
    end

    puts 'All prerequisites satisfied:'
    puts "  SWIG: #{swig}"
    puts "  RDKit: #{rdkit_dir}"
    puts "  RDKit includes: #{rdkit_include_dirs.join(', ')}"
    puts "  Boost: #{boost_dir}"
    puts "  Ruby: #{ruby_include_paths.join(', ')}"
  end

  desc 'Generate SWIG wrapper from interface files (requires SWIG + headers)'
  task generate: :check do
    swig = swig_executable

    # Build include paths from all RDKit directories
    includes = ["-I#{RUBY_WRAPPERS_DIR}"]

    # Add all RDKit include directories
    rdkit_include_dirs.each do |dir|
      includes << "-I#{dir}"
    end

    # Add Boost
    includes << "-I#{boost_include_dir}"

    # Add Ruby includes
    ruby_include_paths.each do |path|
      includes << "-I#{path}" if path && File.directory?(path)
    end

    # SWIG flags (matching CMakeLists.txt)
    flags = %w[-c++ -ruby -small -naturalvar -autorename]
    flags += feature_flags
    flags += includes

    # Output file
    flags << '-o'
    flags << WRAPPER_FILE

    # Input file
    flags << INTERFACE_FILE

    cmd = "#{swig} #{flags.join(' ')}"
    puts 'Generating SWIG wrapper...'
    puts cmd if ENV['VERBOSE']

    abort 'SWIG generation failed' unless system(cmd)

    puts "Generated: #{WRAPPER_FILE}"

    # Check file size
    size = File.size(WRAPPER_FILE)
    puts "Wrapper size: #{(size / 1024.0 / 1024.0).round(2)} MB"
  end

  desc 'Apply Ruby 3.2+ compatibility patches to generated wrapper'
  task :patch do
    abort "Wrapper file not found: #{WRAPPER_FILE}\nRun 'rake swig:generate' first." unless File.exist?(WRAPPER_FILE)

    puts 'Applying Ruby 3.2+ compatibility patches...'

    content = File.read(WRAPPER_FILE)
    original_size = content.bytesize
    changes = 0

    # Patch 1: The main issue is SWIG's use of Ruby's Data_Wrap_Struct and related macros
    # In Ruby 3.2+, there's a new Data class that conflicts with SWIG's internal usage
    #
    # Key patterns to look for and fix:
    #
    # 1. rb_cData references - SWIG uses this for the base Data class
    # 2. Data_Wrap_Struct - This is actually fine (it's a macro, not the Data class)
    # 3. SWIG's swig_class structures that inherit from Data

    # Pattern 1: Fix rb_cData variable declarations and usages
    # SWIG generates: static VALUE rb_cData;
    # We need to ensure this doesn't conflict with Ruby 3.2+'s Data class
    if content.include?('rb_cData')
      # Replace SWIG's rb_cData with rb_cSwigData to avoid conflict
      content.gsub!(/\brb_cData\b/, 'rb_cSwigData')
      changes += 1
      puts '  - Renamed rb_cData to rb_cSwigData'
    end

    # Pattern 2: Fix any class definition using "Data" as the class name
    # SWIG might generate: rb_define_class_under(mModule, "Data", rb_cObject)
    if content.match?(/rb_define_class(?:_under)?\s*\([^,]+,\s*"Data"/)
      content.gsub!(/rb_define_class(_under)?\s*\(([^,]+),\s*"Data"/) do
        "rb_define_class#{Regexp.last_match(1)}(#{Regexp.last_match(2)}, \"SwigData\""
      end
      changes += 1
      puts "  - Renamed 'Data' class definitions to 'SwigData'"
    end

    # Pattern 3: Fix inheritance from rb_cData
    # SWIG might generate: rb_define_class_under(mModule, "SomeClass", rb_cData)
    # After our rb_cData rename, this should become rb_cSwigData (already handled by Pattern 1)

    # Pattern 4: Check for SWIG_Ruby_NewPointerObj using Data type
    # This is usually fine but let's log if we see it
    puts '  - Found TYPE_DATA usage (usually fine, but verify if issues occur)' if content.include?('TYPE_DATA')

    # Pattern 5: Fix any T_DATA type checks that might conflict
    # T_DATA is a Ruby constant and should be fine, but let's check

    if changes > 0
      # Backup original
      backup_file = "#{WRAPPER_FILE}.orig"
      FileUtils.cp(WRAPPER_FILE, backup_file)
      puts "  - Original backed up to: #{backup_file}"

      # Write patched version
      File.write(WRAPPER_FILE, content)
      new_size = content.bytesize

      puts "Patching complete: #{changes} change(s) applied"
      puts "Size: #{original_size} -> #{new_size} bytes"
    else
      puts 'No Ruby 3.2+ compatibility issues found (wrapper may already be compatible)'
    end
  end

  desc 'Generate and patch wrapper in one step'
  task build: %i[generate patch]

  desc 'Remove generated wrapper files'
  task :clean do
    [WRAPPER_FILE, WRAPPER_HEADER, "#{WRAPPER_FILE}.orig"].each do |file|
      if File.exist?(file)
        FileUtils.rm(file)
        puts "Removed: #{file}"
      end
    end
  end

  desc 'Check wrapper status'
  task :status do
    puts 'SWIG Wrapper Status'
    puts '=' * 40

    if File.exist?(WRAPPER_FILE)
      stat = File.stat(WRAPPER_FILE)
      puts "Wrapper: #{WRAPPER_FILE}"
      puts "  Size: #{(stat.size / 1024.0 / 1024.0).round(2)} MB"
      puts "  Modified: #{stat.mtime}"

      # Check if patched
      content = File.read(WRAPPER_FILE, 1000) # Read first 1000 bytes
      if content.include?('rb_cSwigData')
        puts '  Ruby 3.2+ patch: APPLIED'
      else
        puts "  Ruby 3.2+ patch: NOT APPLIED (may need 'rake swig:patch')"
      end

      # Check for backup
      puts "  Backup: #{WRAPPER_FILE}.orig exists" if File.exist?("#{WRAPPER_FILE}.orig")
    else
      puts 'Wrapper: NOT GENERATED'
      puts "  Run 'rake swig:generate' to create"
    end

    puts ''
    puts "Interface file: #{File.exist?(INTERFACE_FILE) ? 'EXISTS' : 'MISSING'}"

    # Count .i files
    i_files = Dir.glob("#{RUBY_WRAPPERS_DIR}/**/*.i").count
    puts "Interface files: #{i_files} .i files found"
  end

  desc 'Show SWIG command that would be run (dry run)'
  task dry_run: :check do
    swig = swig_executable

    # Build include paths from all RDKit directories
    includes = ["-I#{RUBY_WRAPPERS_DIR}"]

    # Add all RDKit include directories
    rdkit_include_dirs.each do |dir|
      includes << "-I#{dir}"
    end

    # Add Boost
    includes << "-I#{boost_include_dir}"

    # Add Ruby includes
    ruby_include_paths.each do |path|
      includes << "-I#{path}" if path && File.directory?(path)
    end

    flags = %w[-c++ -ruby -small -naturalvar -autorename]
    flags += feature_flags
    flags += includes
    flags << '-o'
    flags << WRAPPER_FILE
    flags << INTERFACE_FILE

    puts 'Would run:'
    puts "#{swig} \\"
    flags.each_with_index do |flag, i|
      suffix = i < flags.length - 1 ? ' \\' : ''
      puts "  #{flag}#{suffix}"
    end
  end
end
