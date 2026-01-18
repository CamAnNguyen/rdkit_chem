# frozen_string_literal: true

require 'fileutils'
require 'rbconfig'
require 'mkmf'

main_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
$LOAD_PATH.unshift File.join(main_dir, 'lib')
require 'rdkit_chem/version'

rdkit_dir = File.join(main_dir, 'rdkit')
install_dir = File.join(main_dir, 'rdkit_chem')
src_dir = rdkit_dir
build_dir = File.join(src_dir, 'build')

begin
  nr_processors = `getconf _NPROCESSORS_ONLN`.to_i # should be POSIX compatible
rescue StandardError
  nr_processors = 1
end

# Detect build system: prefer Ninja if available (2-3x faster), fallback to Make
def detect_build_system
  # Allow override via environment variable
  if ENV['CMAKE_GENERATOR']
    generator = ENV['CMAKE_GENERATOR']
    if generator.downcase.include?('ninja')
      return { generator: 'Ninja', command: 'ninja', available: system('which ninja > /dev/null 2>&1') }
    end

    return { generator:, command: 'make', available: true }

  end

  # Auto-detect: prefer Ninja if installed
  if system('which ninja > /dev/null 2>&1')
    { generator: 'Ninja', command: 'ninja', available: true }
  else
    { generator: 'Unix Makefiles', command: 'make', available: true }
  end
end

build_system = detect_build_system
puts "Using build system: #{build_system[:generator]}"

FileUtils.mkdir_p rdkit_dir
Dir.chdir main_dir do
  FileUtils.rm_rf src_dir
  puts 'Downloading RDKit sources'
  git = 'git clone https://github.com/rdkit/rdkit.git'
  system git
end

Dir.chdir(src_dir) do
  checkout = "git checkout #{RDKitChem::RDKIT_COMMIT}"
  system checkout
end

FileUtils.cp_r(
  File.join(main_dir, 'Code'),
  File.join(rdkit_dir),
  remove_destination: true
)

FileUtils.cp_r(
  File.join(main_dir, 'CMakeLists.txt'),
  File.join(rdkit_dir),
  remove_destination: true
)

host_os = RbConfig::CONFIG['host_os']
is_linux = host_os =~ /linux/
is_mac = host_os =~ /darwin/
ld_path = ''

if is_linux || is_mac
  ld_string = is_linux ? 'LD_LIBRARY_PATH' : 'DYLD_LIBRARY_PATH'
  ld_path = "#{ld_string}=#{install_dir}/lib"
  env_ld = ENV[ld_string] || ''

  ld_path += ":#{env_ld}" unless env_ld.empty?
end

FileUtils.mkdir_p build_dir
Dir.chdir build_dir do
  puts 'Configuring RDKit'

  # Build options
  cmake_opts = [
    '-DRDK_INSTALL_INTREE=OFF',
    "-DCMAKE_INSTALL_PREFIX=#{install_dir}",
    '-DCMAKE_BUILD_TYPE=Release',
    '-DRDK_BUILD_PYTHON_WRAPPERS=OFF',
    '-DRDK_BUILD_SWIG_WRAPPERS=ON',
    '-DRDK_BUILD_SWIG_RUBY_WRAPPER=ON',
    '-DRDK_BUILD_INCHI_SUPPORT=OFF',
    '-DRDK_BUILD_CHEMDRAW_SUPPORT=ON',
    '-DBoost_NO_BOOST_CMAKE=ON'
  ]

  # On macOS, use STATIC linking for the SWIG wrapper
  # This bundles all RDKit libraries into a single RDKitChem.bundle file,
  # which avoids SWIG type table initialization issues across multiple dylibs.
  # The "wrong argument type nil (expected Data)" error on macOS is caused by
  # SWIG's type registry not being properly shared across dynamic libraries.
  # Static linking solves this by keeping everything in one binary.
  if is_mac
    cmake_opts << '-DRDK_SWIG_STATIC=ON'
    cmake_opts << '-DRDK_INSTALL_STATIC_LIBS=ON'
    cmake_opts << '-DBUILD_SHARED_LIBS=OFF'
    puts 'macOS: Using static-only build (no dylibs)'

    if ENV['BOOST_ROOT']
      boost_root = ENV['BOOST_ROOT']
      cmake_opts << "-DBOOST_ROOT=#{boost_root}"
      cmake_opts << '-DBoost_NO_SYSTEM_PATHS=ON'
      cmake_opts << '-DBoost_USE_STATIC_LIBS=ON'
      puts "Using custom Boost from: #{boost_root}"
    end
  end

  cmake_opts << "-G \"#{build_system[:generator]}\""

  cmake = "#{ld_path} cmake #{src_dir} #{cmake_opts.join(' ')}"
  system cmake
end

Dir.chdir build_dir do
  puts 'Compiling RDKit sources.'
  if build_system[:command] == 'ninja'
    system "#{ld_path} ninja"
    system "#{ld_path} ninja install"
  else
    system "#{ld_path} make -j#{nr_processors}"
    system "#{ld_path} make install"
  end
end

# Remove compiled file, free spaces
FileUtils.remove_dir(rdkit_dir)

# create a fake Makefile
File.open(File.join(File.dirname(__FILE__), 'Makefile'), 'w+') do |makefile|
  makefile.puts "all:\n\ttrue\n\ninstall:\n\ttrue\n"
end

$makefile_created = true
