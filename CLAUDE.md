# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is `rdkit_chem`, a Ruby gem that provides Ruby bindings for [RDKit](http://rdkit.org/), an Open-Source Cheminformatics Software library. The gem uses SWIG to generate Ruby wrappers around RDKit's C++ codebase.

**Ruby Namespace**: All RDKit classes are exposed under the `RDKitChem` Ruby module (not `RDKit`).

## Current State (December 2024)

### What Works
- Basic molecule operations: SMILES parsing, mol block conversion, atom counting
- The gem builds successfully on Linux x86_64
- Pre-compiled gem packaging is supported
- Tests pass (5 tests in `test/test_rdkit_chem.rb`)

### Gem Distribution Model
The gem supports two distribution modes (similar to nokogiri):

1. **Source gem** (`rdkit_chem-x.x.x.gem`): Compiles RDKit from source during `gem install` (~30 min build time)
2. **Pre-compiled gem** (`rdkit_chem-x.x.x-x86_64-linux.gem`): Instant install with bundled binaries

When users run `gem install rdkit_chem`, RubyGems automatically selects the platform-specific gem if available.

## Build Process

### Source Build (from gem install)
When installed via `gem install rdkit_chem` (source gem):

1. `ext/rdkit_chem/extconf.rb` clones the official RDKit repository
2. Checks out commit `c2e48f41d88ddc15c6e1f818d1c4ced70b7f20d1`
3. Copies this repo's `Code/` and `CMakeLists.txt` over the cloned source
4. Runs CMake with SWIG Ruby wrapper options enabled
5. Compiles RDKit with Ruby bindings (~30 minutes)
6. Installs to `rdkit_chem/lib/` within the gem directory

### Pre-compiled Gem Build
After compiling once, you can package a pre-compiled gem:

```bash
rake fix_rpath      # Set RPATH on all .so files (required for portability)
rake test_native    # Verify extension loads without LD_LIBRARY_PATH
rake build_native   # Package pre-compiled gem for current platform
```

## Rake Tasks

| Task | Description |
|------|-------------|
| `rake test` | Run test suite (requires LD_LIBRARY_PATH for source builds) |
| `rake fix_rpath` | Apply RPATH fix to all .so files using patchelf |
| `rake test_native` | Test that extension loads without LD_LIBRARY_PATH |
| `rake build` | Build source gem |
| `rake build_native` | Build pre-compiled platform-specific gem |
| `rake clean` | Remove gem files and temp directories |

## Architecture

```
rdkit_chem/
├── CMakeLists.txt              # Modified RDKit CMake config
├── Code/
│   ├── CMakeLists.txt          # Includes RubyWrappers subdirectory
│   └── RubyWrappers/           # SWIG interface files (.i)
│       ├── CMakeLists.txt      # Links required RDKit libraries
│       ├── gmwrapper/
│       │   └── GraphMolRuby.i  # Main SWIG module definition
│       └── *.i                 # Individual wrapper definitions
├── ext/rdkit_chem/
│   └── extconf.rb              # Ruby gem native extension builder
├── lib/
│   ├── rdkit_chem.rb           # Main entry point (finds native extension)
│   └── rdkit_chem/version.rb
├── rdkit_chem/lib/             # Compiled libraries (after build)
│   ├── RDKitChem.so            # Main Ruby extension
│   └── libRDKit*.so*           # ~70 RDKit shared libraries
├── Rakefile                    # Build tasks
├── rdkit_chem.gemspec          # Gem specification (dual-mode)
└── test/
    └── test_rdkit_chem.rb
```

## Ruby SWIG-Specific Issues (IMPORTANT)

The Ruby SWIG wrappers required several fixes compared to Java/Python wrappers:

### 1. `swig::traits` Redefinition Errors
**Problem**: Ruby SWIG generates duplicate `swig::traits` definitions when using `boost::int32_t` or `boost::uint32_t` because these are typedefs to `int`/`unsigned int`.

**Solution**: Use base types (`int`, `unsigned int`) instead of boost types in `%template` directives:
```swig
// WRONG - causes redefinition error
%template(SparseIntVect32) RDKit::SparseIntVect<boost::int32_t>;

// CORRECT
%template(SparseIntVect32) RDKit::SparseIntVect<int>;
```

**Files affected**: `AtomPairs.i`, `MorganFingerprints.i`, `Fingerprints.i`, `GraphMolRuby.i`

### 2. `long long` Type Not Supported
**Problem**: Ruby SWIG lacks `swig::traits` for `long long int` (boost::int64_t).

**Solution**: Remove or comment out templates using 64-bit types:
```swig
// SparseIntVect64 removed - Ruby SWIG lacks swig::traits for long long int
// %template(SparseIntVect64) RDKit::SparseIntVect<boost::int64_t>;
```

### 3. `%ignore` Must Come Before `%include`
**Problem**: SWIG processes directives in order. If `%ignore` comes after `%include`, the function is already wrapped.

**Solution**: Always place `%ignore` directives before the corresponding `%include`:
```swig
// CORRECT order
%ignore RDKit::MolOps::sanitizeMol;
%include <GraphMol/MolOps.h>
```

### 4. Return Type Warnings
**Problem**: `%extend` blocks with `setElement()` functions returning values from void expressions cause `-Wreturn-type` warnings.

**Solution**: Change return type to `void`:
```swig
%extend boost::shared_array<double> {
  void setElement(int i, double value) {  // void, not double
    (*($self))[i] = value;
  }
}
```

## RPATH and Library Loading

### The Problem
After compilation, `RDKitChem.so` depends on ~70 `libRDKit*.so` libraries. Without RPATH, you need `LD_LIBRARY_PATH`:
```bash
LD_LIBRARY_PATH=/path/to/rdkit_chem/lib ruby -e "require 'rdkit_chem'"
```

### The Solution
Use `patchelf` to set RPATH to `$ORIGIN` on ALL shared libraries:
```bash
rake fix_rpath  # Sets RPATH on all .so files
```

This allows the libraries to find each other relative to their location, eliminating the need for `LD_LIBRARY_PATH`.

### Library Loading Flow
`lib/rdkit_chem.rb` searches for the native extension in:
1. `lib/rdkit_chem/<ruby_version>/` (pre-compiled gem location)
2. `rdkit_chem/lib/` (source-compiled location)

## CMake Options

The build enables these RDKit options by default:
- `RDK_BUILD_SWIG_WRAPPERS=ON`
- `RDK_BUILD_SWIG_RUBY_WRAPPER=ON`
- `RDK_BUILD_PYTHON_WRAPPERS=OFF`

## Linked Libraries

The Ruby wrapper links against these RDKit libraries (defined in `Code/RubyWrappers/CMakeLists.txt`):
- ScaffoldNetwork, MolHash, RGroupDecomposition, SubstructLibrary
- MolStandardize, FilterCatalog, Catalogs, FMCS, MolDraw2D
- FileParsers, SmilesParse, Depictor, SubstructMatch
- ChemReactions, Fingerprints, ChemTransforms, Subgraphs
- GraphMol, DataStructs, Trajectory, Descriptors
- PartialCharges, MolTransforms, DistGeomHelpers, DistGeometry
- ForceFieldHelpers, ForceField, EigenSolvers, Optimizer, MolAlign
- Alignment, SimDivPickers, RDGeometryLib, RDStreams, RDGeneral
- Abbreviations, GeneralizedSubstruct, MolEnumerator, TautomerQuery, RascalMCES

If you add new SWIG wrappers that use additional RDKit functionality, you may need to add libraries to this list.

## Modifying SWIG Wrappers

When adding new RDKit functionality to Ruby bindings:
1. Create or modify `.i` files in `Code/RubyWrappers/`
2. Include new `.i` files in `gmwrapper/GraphMolRuby.i`
3. Use `%shared_ptr()` for classes managed by shared pointers
4. Use base types (`int`, `unsigned int`) instead of boost typedefs
5. Place `%ignore` directives BEFORE `%include` statements
6. Add any new required libraries to `Code/RubyWrappers/CMakeLists.txt`

## Testing

```bash
# With source build (needs LD_LIBRARY_PATH)
LD_LIBRARY_PATH=rdkit_chem/lib rake test

# After fix_rpath (no LD_LIBRARY_PATH needed)
rake test

# Test native loading without LD_LIBRARY_PATH
rake test_native
```

## Quick Reference

```bash
# Full workflow for building pre-compiled gem
gem build rdkit_chem.gemspec && gem install rdkit_chem-*.gem  # Build from source
rake fix_rpath                                                  # Fix RPATH
rake test_native                                                # Verify
rake build_native                                               # Package

# Publishing (example)
gem push rdkit_chem-2025.09.3.1.gem              # Source gem
gem push rdkit_chem-2025.09.3.1-x86_64-linux.gem # Pre-compiled
```
