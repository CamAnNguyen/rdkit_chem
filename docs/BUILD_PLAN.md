# Zero-Runtime-Dependency Build Plan for rdkit_chem

## Executive Summary

This plan transforms `rdkit_chem` from a "compile-on-install" gem to a **pre-compiled, zero-dependency gem** using Ruby's equivalent of Python's wheel infrastructure.

---

## Part 1: Architecture Comparison

### Python vs Ruby Tooling

| Function | Python | Ruby Equivalent |
|----------|--------|-----------------|
| **Build orchestrator** | `cibuildwheel` | `rake-compiler` + `rake-compiler-dock` |
| **Library bundler** | `auditwheel` (Linux) | `patchelf` (manual) → **needs automation** |
| **Library bundler** | `delocate` (macOS) | `install_name_tool` (manual) |
| **Library bundler** | `delvewheel` (Windows) | Manual DLL copying |
| **Portable build env** | `manylinux` Docker | `rake-compiler-dock` images |
| **Platform tags** | `cp312-manylinux_x86_64` | `x86_64-linux` |
| **Package format** | `.whl` (ZIP) | `.gem` (TAR+GZ) |

### Current rdkit_chem Gaps

| What You Have | What's Missing |
|---------------|----------------|
| `rake fix_rpath` | Automated in CI |
| `rake build_native` | Cross-platform matrix |
| `rake bundle_system_libs` | Comprehensive dependency detection |
| Manual patchelf | Automated repair step |
| Single platform | Multi-platform (Linux x86_64, ARM64, macOS, Windows) |

---

## Part 2: Target Build Pipeline

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GitHub Actions CI                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐ │
│  │ x86_64-linux │   │ aarch64-linux│   │ arm64-darwin │   │x64-mingw-ucrt│ │
│  │  (glibc)     │   │   (glibc)    │   │  (macOS M1+) │   │  (Windows)   │ │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘ │
│         │                  │                  │                  │          │
│         ▼                  ▼                  ▼                  ▼          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    rake-compiler-dock containers                      │  │
│  │  • Ruby 3.1, 3.2, 3.3, 3.4, 4.0                                       │  │
│  │  • Pre-installed: cmake, boost, eigen, swig                          │  │
│  │  • Cross-compilation toolchains                                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         Build Steps                                   │  │
│  │  1. Clone RDKit @ pinned commit                                      │  │
│  │  2. Overlay Code/ and CMakeLists.txt                                 │  │
│  │  3. cmake && make -jN                                                │  │
│  │  4. REPAIR: bundle deps + fix RPATH (auditwheel equivalent)          │  │
│  │  5. Package: rake native gem                                         │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         Test Matrix                                   │  │
│  │  • Platforms: Linux, macOS (Intel+ARM), Windows                      │  │
│  │  • Ruby versions: 3.1, 3.2, 3.3                                      │  │
│  │  • Test 1: Basic load test (require 'rdkit_chem')                    │  │
│  │  • Test 2: Smoke test (SMILES, MolBlock, atom/bond counts)           │  │
│  │  • Test 3: Full test suite (rake test)                               │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         Publish                                       │  │
│  │  gem push rdkit_chem-VERSION.gem                    (source)         │  │
│  │  gem push rdkit_chem-VERSION-x86_64-linux.gem       (precompiled)    │  │
│  │  gem push rdkit_chem-VERSION-aarch64-linux.gem                       │  │
│  │  gem push rdkit_chem-VERSION-arm64-darwin.gem                        │  │
│  │  gem push rdkit_chem-VERSION-x64-mingw-ucrt.gem                      │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 3: Implementation Plan

### Phase 1: Local Tooling Enhancement

#### 1.1 Create `rake repair` Task (Ruby's auditwheel)

```ruby
# Rakefile additions

# Libraries that are safe to depend on (present on all target systems)
SYSTEM_LIBS_ALLOWLIST = %w[
  libc.so
  libm.so
  libpthread.so
  libdl.so
  librt.so
  libstdc++.so
  libgcc_s.so
  linux-vdso.so
  ld-linux
].freeze

# Libraries that MUST be bundled
BUNDLE_LIBS = %w[
  libboost_*.so*
  libRDKit*.so*
  libfreetype.so*
  libpng*.so*
  libz.so*
].freeze

desc 'Repair wheel: bundle all dependencies and fix RPATH (like auditwheel)'
task :repair do
  require 'set'
  
  so_file = File.join(NATIVE_DIR, 'RDKitChem.so')
  libs_dir = NATIVE_DIR
  
  # Step 1: Find all dependencies recursively
  puts "Scanning dependencies..."
  needed_libs = find_all_dependencies(so_file, libs_dir)
  
  # Step 2: Copy external dependencies into libs_dir
  puts "Bundling #{needed_libs.size} libraries..."
  needed_libs.each do |lib_path|
    dest = File.join(libs_dir, File.basename(lib_path))
    unless File.exist?(dest)
      FileUtils.cp(lib_path, dest, verbose: true)
    end
  end
  
  # Step 3: Fix RPATH on ALL .so files
  puts "Fixing RPATH..."
  Dir.glob("#{libs_dir}/*.so*").each do |lib|
    next if File.symlink?(lib)
    system("patchelf --set-rpath '$ORIGIN' '#{lib}'")
  end
  
  # Step 4: Verify
  puts "\nVerifying no external dependencies..."
  verify_self_contained(so_file, libs_dir)
end

def find_all_dependencies(so_file, libs_dir)
  # Use ldd to find all transitive dependencies
  ldd_output = `ldd #{so_file} 2>/dev/null`
  
  external_libs = Set.new
  
  ldd_output.each_line do |line|
    # Parse: libboost_serialization.so.1.74.0 => /usr/lib/x86_64-linux-gnu/libboost_serialization.so.1.74.0
    if line =~ /^\s+(\S+)\s+=>\s+(\S+)/
      lib_name, lib_path = $1, $2
      
      # Skip system libraries (libc, libm, libpthread, etc.)
      next if lib_path.start_with?('/lib64/', '/lib/x86_64-linux-gnu/libc', 
                                    '/lib/x86_64-linux-gnu/libm',
                                    '/lib/x86_64-linux-gnu/libpthread',
                                    '/lib/x86_64-linux-gnu/libdl',
                                    '/lib/x86_64-linux-gnu/librt')
      next if lib_name.start_with?('linux-vdso', 'ld-linux')
      
      # Skip if already in our libs_dir
      next if File.exist?(File.join(libs_dir, File.basename(lib_path)))
      
      # Add external dependency
      external_libs.add(lib_path) if File.exist?(lib_path)
    end
  end
  
  external_libs
end

def verify_self_contained(so_file, libs_dir)
  # Check that all dependencies resolve within libs_dir
  env = { 'LD_LIBRARY_PATH' => '' }
  result = system(env, "ldd #{so_file} | grep 'not found'")
  
  if result
    abort "ERROR: Some dependencies not bundled!"
  else
    puts "✓ All dependencies self-contained"
  end
end
```

---

### Phase 2: rake-compiler Integration

#### 2.1 Install Dependencies

```bash
# Add to gemspec
gem.add_development_dependency 'rake-compiler', '~> 1.2'
gem.add_development_dependency 'rake-compiler-dock', '~> 1.5'
```

#### 2.2 Rakefile Updates

```ruby
# Rakefile
require 'rake/extensiontask'

Rake::ExtensionTask.new('rdkit_chem') do |ext|
  ext.lib_dir = 'lib/rdkit_chem'
  ext.cross_compile = true
  ext.cross_platform = %w[
    x86_64-linux
    aarch64-linux
    arm64-darwin
    x64-mingw-ucrt
  ]
  
  # Custom compile task since we use CMake, not mkmf
  ext.cross_compiling do |spec|
    spec.files += Dir['lib/rdkit_chem/**/*.so*']
    spec.files += Dir['lib/rdkit_chem/**/*.dylib']
    spec.files += Dir['lib/rdkit_chem/**/*.dll']
  end
end

# Override the compile step to use CMake
namespace :compile do
  task :rdkit_chem do
    # Our custom CMake build
    Rake::Task['cmake_build'].invoke
    Rake::Task['repair'].invoke
  end
end
```

---

### Phase 3: Docker Build Environment

#### 3.1 Custom Dockerfile (extends rake-compiler-dock)

```dockerfile
# Dockerfile.build
ARG RCD_IMAGE=ghcr.io/rake-compiler/rake-compiler-dock-image:1.5.0-mri-x86_64-linux

FROM ${RCD_IMAGE}

# Install RDKit build dependencies
RUN yum install -y \
    cmake3 \
    boost-devel \
    boost-python3-devel \
    eigen3-devel \
    swig \
    freetype-devel \
    libpng-devel \
    zlib-devel \
    sqlite-devel \
    patchelf \
    && yum clean all

# Symlink cmake3 to cmake
RUN ln -sf /usr/bin/cmake3 /usr/bin/cmake

# Set environment
ENV RDKIT_BUILD_DIR=/build/rdkit
ENV CMAKE_BUILD_PARALLEL_LEVEL=4

WORKDIR /gem
```

#### 3.2 Build Script

```bash
#!/bin/bash
# scripts/build-native-gem.sh

set -e

PLATFORM=${1:-x86_64-linux}
RUBY_VERSIONS=${2:-"3.1.0 3.2.0 3.3.0 3.4.0 4.0.0"}

echo "Building rdkit_chem for platform: $PLATFORM"
echo "Ruby versions: $RUBY_VERSIONS"

for RUBY_VERSION in $RUBY_VERSIONS; do
    echo "=== Building for Ruby $RUBY_VERSION ==="
    
    # Use rake-compiler-dock for Linux builds
    if [[ "$PLATFORM" == *linux* ]]; then
        docker run --rm -v "$(pwd):/gem" -w /gem \
            -e RUBY_CC_VERSION=$RUBY_VERSION \
            ghcr.io/rake-compiler/rake-compiler-dock-image:1.5.0-mri-$PLATFORM \
            bash -c "
                bundle install &&
                rake cmake_build &&
                rake repair &&
                rake native:$PLATFORM gem
            "
    fi
done

echo "=== Build complete ==="
ls -la pkg/*.gem
```

---

### Phase 4: GitHub Actions CI/CD

#### 4.1 Main Workflow

```yaml
# .github/workflows/build-native-gems.yml
name: Build Native Gems

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build-linux:
    name: Build Linux (${{ matrix.platform }})
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        platform:
          - x86_64-linux
          - aarch64-linux
        ruby:
          - '3.1'
          - '3.2'
          - '3.3'
          - '3.4'
          - '4.0'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up QEMU (for ARM builds)
        if: matrix.platform == 'aarch64-linux'
        uses: docker/setup-qemu-action@v3
        with:
          platforms: arm64
      
      - name: Build native gem
        run: |
          docker run --rm \
            --platform linux/${{ matrix.platform == 'aarch64-linux' && 'arm64' || 'amd64' }} \
            -v "${{ github.workspace }}:/gem" \
            -w /gem \
            -e TARGET_RUBY=${{ matrix.ruby }} \
            ghcr.io/rake-compiler/rake-compiler-dock-image:1.5.0-mri-${{ matrix.platform }} \
            bash -c "
              gem install bundler &&
              bundle install &&
              ./scripts/build-in-container.sh
            "
      
      - name: Upload gem artifact
        uses: actions/upload-artifact@v4
        with:
          name: gem-${{ matrix.platform }}-ruby${{ matrix.ruby }}
          path: pkg/*.gem

  build-macos:
    name: Build macOS (${{ matrix.arch }})
    runs-on: ${{ matrix.runner }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - runner: macos-13      # Intel
            arch: x86_64-darwin
          - runner: macos-14      # Apple Silicon
            arch: arm64-darwin
        ruby:
          - '3.1'
          - '3.2'
          - '3.3'
          - '3.4'
          - '4.0'
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby }}
      
      - name: Install dependencies
        run: |
          brew install cmake boost eigen swig freetype libpng
      
      - name: Build native gem
        run: |
          bundle install
          rake cmake_build
          rake repair_macos
          rake build_native
      
      - name: Upload gem artifact
        uses: actions/upload-artifact@v4
        with:
          name: gem-${{ matrix.arch }}-ruby${{ matrix.ruby }}
          path: '*.gem'

  build-windows:
    name: Build Windows
    runs-on: windows-latest
    strategy:
      matrix:
        ruby:
          - '3.1'
          - '3.2'
          - '3.3'
          - '3.4'
          - '4.0'
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby }}
      
      - name: Install dependencies
        run: |
          vcpkg install boost:x64-windows eigen3:x64-windows
          choco install swig cmake
      
      - name: Build native gem
        run: |
          bundle install
          rake cmake_build
          rake repair_windows
          rake build_native
      
      - name: Upload gem artifact
        uses: actions/upload-artifact@v4
        with:
          name: gem-x64-mingw-ucrt-ruby${{ matrix.ruby }}
          path: '*.gem'

  test:
    name: Test (${{ matrix.os }}, Ruby ${{ matrix.ruby }})
    needs: [build-linux, build-macos, build-windows]
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, ubuntu-22.04, macos-13, macos-14, windows-latest]
        ruby: ['3.1', '3.2', '3.3', '3.4', '4.0']
    
    steps:
      - uses: actions/checkout@v4
      
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby }}
      
      - name: Download gem
        uses: actions/download-artifact@v4
        with:
          pattern: gem-*
          merge-multiple: true
      
      - name: Install gem
        run: |
          gem install rdkit_chem-*.gem
        shell: bash
      
      - name: Test 1 - Basic load test
        run: |
          ruby -e "require 'rdkit_chem'; puts 'Loaded RDKitChem version: ' + RDKitChem::VERSION"
        shell: bash
      
      - name: Test 2 - Smoke test (core functionality)
        run: |
          ruby -e "
            require 'rdkit_chem'
            
            # Test SMILES parsing
            mol = RDKitChem.MolFromSmiles('CCO')
            raise 'SMILES parse failed' unless mol
            
            # Test atom count
            raise 'Atom count wrong: expected 3' unless mol.GetNumAtoms == 3
            
            # Test bond count
            raise 'Bond count wrong: expected 2' unless mol.GetNumBonds == 2
            
            # Test mol block generation
            molblock = RDKitChem.MolToMolBlock(mol)
            raise 'MolBlock generation failed' if molblock.nil? || molblock.empty?
            
            # Test SMILES round-trip
            smiles = RDKitChem.MolToSmiles(mol)
            raise 'SMILES generation failed' if smiles.nil? || smiles.empty?
            
            puts 'All smoke tests passed!'
          "
        shell: bash
      
      - name: Test 3 - Full test suite
        run: |
          bundle install
          rake test
        shell: bash

  publish:
    name: Publish to RubyGems
    needs: test
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    
    steps:
      - name: Download all gems
        uses: actions/download-artifact@v4
        with:
          pattern: gem-*
          merge-multiple: true
      
      - name: Setup RubyGems credentials
        run: |
          mkdir -p ~/.gem
          echo ":rubygems_api_key: ${{ secrets.RUBYGEMS_API_KEY }}" > ~/.gem/credentials
          chmod 600 ~/.gem/credentials
      
      - name: Publish gems
        run: |
          for gem in *.gem; do
            echo "Publishing $gem..."
            gem push "$gem"
          done
```

---

### Phase 5: Platform-Specific Repair Tasks

```ruby
# Rakefile additions

desc 'Repair for Linux (patchelf)'
task :repair_linux do
  Dir.glob("#{NATIVE_DIR}/*.so*").each do |lib|
    next if File.symlink?(lib)
    system("patchelf --set-rpath '$ORIGIN' '#{lib}'")
  end
end

desc 'Repair for macOS (install_name_tool)'
task :repair_macos do
  libs_dir = File.expand_path(NATIVE_DIR)
  
  Dir.glob("#{libs_dir}/*.dylib").each do |lib|
    # Change install name to @loader_path
    lib_name = File.basename(lib)
    system("install_name_tool -id @loader_path/#{lib_name} '#{lib}'")
    
    # Update all dependency references
    otool_output = `otool -L '#{lib}'`
    otool_output.each_line do |line|
      if line =~ /^\s+(.+\.dylib)/
        dep_path = $1.strip.split(' ').first
        dep_name = File.basename(dep_path)
        
        # Only fix non-system libraries
        unless dep_path.start_with?('/usr/lib/', '/System/')
          system("install_name_tool -change '#{dep_path}' '@loader_path/#{dep_name}' '#{lib}'")
        end
      end
    end
  end
end

desc 'Repair for Windows (copy DLLs)'
task :repair_windows do
  # Windows doesn't have RPATH; DLLs must be in same directory or PATH
  # Copy all dependent DLLs to the extension directory
  
  dll_search_paths = [
    ENV['VCPKG_ROOT'] + '/installed/x64-windows/bin',
    'C:/boost/lib',
  ]
  
  # Use dumpbin to find dependencies
  dumpbin_output = `dumpbin /dependents #{NATIVE_DIR}/RDKitChem.dll`
  
  dumpbin_output.scan(/^\s+(\S+\.dll)/i).flatten.each do |dll|
    dll_search_paths.each do |search_path|
      src = File.join(search_path, dll)
      if File.exist?(src)
        FileUtils.cp(src, NATIVE_DIR, verbose: true)
        break
      end
    end
  end
end
```

---

## Part 4: Directory Structure (Final)

```
rdkit_chem/
├── .github/
│   └── workflows/
│       └── build-native-gems.yml      # CI/CD pipeline
├── scripts/
│   ├── build-in-container.sh          # Docker build script
│   └── repair-wheel.rb                # Ruby auditwheel equivalent
├── docker/
│   └── Dockerfile.build               # Custom build image
├── ext/rdkit_chem/
│   └── extconf.rb                     # Source build (unchanged)
├── lib/
│   ├── rdkit_chem.rb
│   ├── rdkit_chem/
│   │   ├── version.rb
│   │   ├── 3.1.0/                     # Pre-compiled for Ruby 3.1
│   │   │   ├── RDKitChem.so
│   │   │   └── libRDKit*.so*
│   │   ├── 3.2.0/                     # Pre-compiled for Ruby 3.2
│   │   ├── 3.3.0/                     # Pre-compiled for Ruby 3.3
│   │   ├── 3.4.0/                     # Pre-compiled for Ruby 3.4
│   │   └── 4.0.0/                     # Pre-compiled for Ruby 4.0
├── Code/                               # SWIG wrappers (unchanged)
├── CMakeLists.txt                      # RDKit build config (unchanged)
├── Rakefile                            # Enhanced with repair tasks
└── rdkit_chem.gemspec                  # Dual-mode (unchanged)
```

---

## Part 5: User Experience (Final Result)

```bash
# User on ANY supported platform:
$ gem install rdkit_chem

# RubyGems automatically selects:
# - rdkit_chem-2025.09.3-x86_64-linux.gem  (Linux Intel)
# - rdkit_chem-2025.09.3-aarch64-linux.gem (Linux ARM)
# - rdkit_chem-2025.09.3-arm64-darwin.gem  (macOS M1/M2)
# - rdkit_chem-2025.09.3-x64-mingw-ucrt.gem (Windows)

# Instant install, zero compilation, zero runtime dependencies:
$ ruby -e "require 'rdkit_chem'; puts RDKitChem.MolFromSmiles('CCO').GetNumAtoms"
3
```

---

## Part 6: Implementation Timeline

| Phase | Task | Effort | Priority |
|-------|------|--------|----------|
| **1** | Enhance `rake repair` task | 2-3 days | High |
| **2** | Integrate rake-compiler | 1-2 days | High |
| **3** | Create Docker build environment | 2-3 days | High |
| **4** | GitHub Actions CI/CD | 3-5 days | High |
| **5** | macOS support (install_name_tool) | 2-3 days | Medium |
| **6** | Windows support (vcpkg + DLL copying) | 3-5 days | Medium |
| **7** | Testing across distributions | 2-3 days | High |
| **8** | Documentation | 1 day | Low |

**Total estimated effort**: 2-4 weeks

---

## Part 7: Summary

| Aspect | Current State | Target State |
|--------|---------------|--------------|
| Install time | ~30 minutes | Instant |
| Dependencies | cmake, boost, swig, etc. | None |
| Platforms | x86_64-linux only | Linux, macOS, Windows (Intel + ARM) |
| Ruby versions | Current only | 3.1, 3.2, 3.3, 3.4, 4.0 |
| Build automation | Manual | Fully automated CI/CD |
| Library bundling | Partial (`fix_rpath`) | Complete (`repair` task) |

---

## Appendix A: Test Matrix Coverage

### Platforms Tested

| OS | Runner | Architecture | Ruby Versions |
|----|--------|--------------|---------------|
| Ubuntu Latest | `ubuntu-latest` | x86_64 | 3.1, 3.2, 3.3, 3.4, 4.0 |
| Ubuntu 22.04 | `ubuntu-22.04` | x86_64 | 3.1, 3.2, 3.3, 3.4, 4.0 |
| macOS Intel | `macos-13` | x86_64 | 3.1, 3.2, 3.3, 3.4, 4.0 |
| macOS Apple Silicon | `macos-14` | arm64 | 3.1, 3.2, 3.3, 3.4, 4.0 |
| Windows | `windows-latest` | x64 | 3.1, 3.2, 3.3, 3.4, 4.0 |

### Test Stages

| Stage | Description | Failure Indicates |
|-------|-------------|-------------------|
| **Test 1: Load** | `require 'rdkit_chem'` | Library loading / RPATH issues |
| **Test 2: Smoke** | Core API calls (SMILES, MolBlock) | Binding / wrapper issues |
| **Test 3: Full** | `rake test` (all unit tests) | Functional regressions |

### Total Test Combinations

- **5 platforms** × **5 Ruby versions** = **25 test jobs**
- Each job runs 3 test stages
- `fail-fast: false` ensures all combinations are tested even if one fails

### Note on Ruby 4.0

Ruby 4.0.1 was released in 2025. Full support is included in the build matrix.

---

## Appendix B: Key References

### Python Ecosystem (Reference)
- **cibuildwheel**: https://cibuildwheel.readthedocs.io/
- **auditwheel**: https://github.com/pypa/auditwheel
- **manylinux**: https://github.com/pypa/manylinux
- **rdkit-pypi**: https://github.com/kuelumbus/rdkit-pypi

### Ruby Ecosystem
- **rake-compiler**: https://github.com/rake-compiler/rake-compiler
- **rake-compiler-dock**: https://github.com/rake-compiler/rake-compiler-dock
- **Nokogiri build system**: https://github.com/sparklemotion/nokogiri

### Tools
- **patchelf** (Linux RPATH): https://github.com/NixOS/patchelf
- **install_name_tool** (macOS): Built into Xcode Command Line Tools
- **dumpbin** (Windows): Part of Visual Studio Build Tools
