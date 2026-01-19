# frozen_string_literal: true

require 'fileutils'
require 'rbconfig'
require 'mkmf'

main_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
rdkit_dir = File.join(main_dir, 'rdkit')
install_dir = File.join(main_dir, 'rdkit_chem')
src_dir = rdkit_dir
build_dir = File.join(src_dir, 'build')

begin
  nr_processors = `getconf _NPROCESSORS_ONLN`.to_i # should be POSIX compatible
rescue StandardError
  nr_processors = 1
end

def run_command(command, description)
  puts description if description
  success = system(command)
  abort "ERROR: #{description || command} failed" unless success
end

FileUtils.mkdir_p rdkit_dir
Dir.chdir main_dir do
  FileUtils.rm_rf src_dir
  run_command('git clone https://github.com/rdkit/rdkit.git', 'Downloading RDKit sources')
end

Dir.chdir(src_dir) do
  run_command('git checkout c2e48f41d88ddc15c6e1f818d1c4ced70b7f20d1', 'Checking out RDKit sources')
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

# macOS-specific compiler flags to fix Ruby header compatibility issues
extra_cmake_flags = ''
if is_mac
  # -Wno-register: Ruby headers use deprecated 'register' keyword (removed in C++17)
  # -DHAVE_ISFINITE=1: Prevents Ruby's finite() from conflicting with std::isfinite
  cxx_flags = '-std=c++17 -stdlib=libc++ -Wno-register -DHAVE_ISFINITE=1'
  extra_cmake_flags = " -DCMAKE_CXX_FLAGS='#{cxx_flags}'"
end

# Explicitly specify Ruby paths to avoid CMake finding system Ruby headers
# This is critical on macOS where Xcode SDK contains incompatible Ruby headers
ruby_executable = RbConfig.ruby
ruby_include_dir = RbConfig::CONFIG['rubyhdrdir']
ruby_arch_include_dir = RbConfig::CONFIG['rubyarchhdrdir']

extra_cmake_flags += " -DRuby_EXECUTABLE=#{ruby_executable}"
extra_cmake_flags += " -DRuby_INCLUDE_DIR=#{ruby_include_dir}"
extra_cmake_flags += " -DRuby_CONFIG_INCLUDE_DIR=#{ruby_arch_include_dir}" if ruby_arch_include_dir
extra_cmake_flags += " -DCMAKE_IGNORE_PREFIX_PATH='/Applications/Xcode.app;/Applications/Xcode_*.app'" if is_mac

if is_linux || is_mac
  ld_string = is_linux ? 'LD_LIBRARY_PATH' : 'DYLD_LIBRARY_PATH'
  ld_path = "#{ld_string}=#{install_dir}/lib"
  env_ld = ENV[ld_string] || ''

  ld_path += ":#{env_ld}" unless env_ld.empty?
end

FileUtils.mkdir_p build_dir
Dir.chdir build_dir do
  cmake = "#{ld_path} cmake #{src_dir} -DRDK_INSTALL_INTREE=OFF " \
          "-DCMAKE_INSTALL_PREFIX=#{install_dir} " \
          '-DCMAKE_BUILD_TYPE=Release -DRDK_BUILD_PYTHON_WRAPPERS=OFF ' \
          '-DRDK_BUILD_SWIG_WRAPPERS=ON -DRDK_BUILD_INCHI_SUPPORT=OFF ' \
          "-DBoost_NO_BOOST_CMAKE=ON -DRDK_USE_BOOST_IOSTREAMS=OFF#{extra_cmake_flags}"
  run_command(cmake, 'Configuring RDKit')
end

# local installation in gem directory
Dir.chdir build_dir do
  run_command("#{ld_path} make -j#{nr_processors}", 'Compiling RDKit sources')
  run_command("#{ld_path} make install", 'Installing RDKit sources')
end

# Remove compiled file, free spaces
FileUtils.remove_dir(rdkit_dir)

# create a fake Makefile
File.open(File.join(File.dirname(__FILE__), 'Makefile'), 'w+') do |makefile|
  makefile.puts "all:\n\ttrue\n\ninstall:\n\ttrue\n"
end

$makefile_created = true
