# SWIG Wrapper Generation Guide

This document explains how the pre-generated SWIG wrapper system works for rdkit_chem.

## Overview

rdkit_chem uses SWIG to generate Ruby bindings for the RDKit C++ library. Instead of requiring SWIG at build time, we pre-generate the wrapper file and commit it to the repository.

### Benefits
- Users don't need SWIG installed to build the gem
- Faster builds (skips SWIG processing)
- Reproducible builds across platforms
- Easier debugging (can inspect/modify generated code)

## Architecture

```
Code/RubyWrappers/
├── gmwrapper/
│   ├── GraphMolRuby.i           # Main SWIG interface (includes all others)
│   ├── GraphMolRuby_wrap.cxx    # Pre-generated wrapper (22MB, committed)
│   └── CMakeLists.txt           # Build config (auto-detects wrapper)
├── *.i                           # 72 interface files (ROMol.i, Atom.i, etc.)
└── GenericRDKitException.h      # Custom exception header

tasks/
└── swig.rake                     # SWIG generation tasks
```

### Build Flow

```
WITH pre-generated wrapper (default):
  CMake detects GraphMolRuby_wrap.cxx exists
  → Compiles directly (no SWIG needed)
  → Links to RDKit libraries
  → Produces RDKitChem.so/.bundle

WITHOUT pre-generated wrapper (dev mode):
  CMake doesn't find wrapper
  → Runs SWIG to generate wrapper
  → Compiles generated code
  → Links to RDKit libraries
  → Produces RDKitChem.so/.bundle
```

## Rake Tasks

All SWIG-related tasks are in `tasks/swig.rake`:

```bash
# Check current status
rake swig:status

# Check if prerequisites are met
rake swig:check

# Generate wrapper (requires SWIG + RDKit headers)
rake swig:generate

# Apply Ruby 3.2+ compatibility patches
rake swig:patch

# Generate and patch in one step
rake swig:build

# Show command without running (dry run)
rake swig:dry_run

# Remove generated wrapper
rake swig:clean
```

## Regenerating the Wrapper

### Prerequisites

1. **SWIG 4.2+** installed
2. **RDKit headers** available (either from a build or installed)
3. **Boost headers** available
4. **Ruby headers** (comes with Ruby)

### On macOS (Recommended)

```bash
# Install dependencies
brew install swig boost

# Option 1: Use headers from a previous rdkit_chem build
# (if rdkit_chem/include/rdkit/ exists from a previous gem install)
rake swig:build

# Option 2: Set paths manually
export RDKIT_INCLUDE_DIR=/path/to/rdkit/Code
export BOOST_INCLUDE_DIR=/usr/local/include
rake swig:build
```

### On Linux

```bash
# Install dependencies
sudo apt install swig libboost-all-dev

# Use headers from previous build or set paths
rake swig:build
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RDKIT_INCLUDE_DIR` | Path to RDKit headers | Auto-detected |
| `BOOST_INCLUDE_DIR` | Path to Boost headers | Auto-detected |
| `SWIG_EXECUTABLE` | Path to SWIG binary | `swig` in PATH |
| `RDK_BUILD_INCHI_SUPPORT` | Set to `1` to enable InChI | Off |
| `RDK_BUILD_AVALON_SUPPORT` | Set to `1` to enable Avalon | Off |
| `RDK_USE_BOOST_IOSTREAMS` | Set to `1` to enable iostreams | Off |
| `VERBOSE` | Set to `1` to show SWIG command | Off |

### Getting RDKit Headers

The easiest way is to use headers from a previous rdkit_chem build:

```bash
# After running: gem install rdkit_chem
# Headers will be at: rdkit_chem/include/rdkit/

# Or build manually:
cd rdkit_chem
ruby ext/rdkit_chem/extconf.rb
# This clones RDKit and builds it, leaving headers in rdkit_chem/include/
```

Alternatively, clone RDKit source just for headers:
```bash
git clone --depth 1 https://github.com/rdkit/rdkit.git
export RDKIT_INCLUDE_DIR=$PWD/rdkit/Code
```

## CMake Integration

The `CMakeLists.txt` in `Code/RubyWrappers/gmwrapper/` handles both modes:

```cmake
# Auto-detected options
option(USE_PREGENERATED_SWIG "Use pre-generated wrapper" ON/OFF)
option(FORCE_SWIG_GENERATION "Force SWIG regeneration" OFF)
```

### Force SWIG Regeneration

```bash
cmake ... -DFORCE_SWIG_GENERATION=ON
```

### Skip Pre-generated Wrapper

```bash
cmake ... -DUSE_PREGENERATED_SWIG=OFF
```

## Ruby 3.2+ Compatibility

### The Issue

Ruby 3.2 introduced a new `Data` class that can conflict with SWIG-generated code that uses the same name.

### Current Status

SWIG 4.4.1 does NOT generate the conflicting pattern. The wrapper appears compatible with Ruby 3.2+.

### If Issues Arise

The `rake swig:patch` task is designed to fix compatibility issues by:
- Renaming `rb_cData` to `rb_cSwigData`
- Renaming `"Data"` class definitions to `"SwigData"`

Run it after generation if you encounter `Data` class conflicts:
```bash
rake swig:generate
rake swig:patch
```

## Troubleshooting

### "Unable to find header X"

The SWIG generation needs proper include paths. Check:
1. RDKit headers exist at `RDKIT_INCLUDE_DIR`
2. `rdkit_chem/include/rdkit/` has installed headers (from a previous build)
3. Run `rake swig:check` to verify prerequisites

### "SWIG not found"

Install SWIG:
```bash
# macOS
brew install swig

# Ubuntu/Debian
sudo apt install swig

# Or set path manually
export SWIG_EXECUTABLE=/path/to/swig
```

### "Boost headers not found"

Install Boost or set path:
```bash
# macOS
brew install boost

# Ubuntu/Debian
sudo apt install libboost-all-dev

# Or set path manually
export BOOST_INCLUDE_DIR=/path/to/boost/include
```

### Large wrapper file (22MB)

This is expected. The wrapper contains bindings for 70+ RDKit modules. Consider:
- Using Git LFS for the wrapper file
- Compressing in releases
- Generating on CI instead of committing

## File Reference

### Interface Files (.i)

Key interface files in `Code/RubyWrappers/`:

| File | Description |
|------|-------------|
| `gmwrapper/GraphMolRuby.i` | Main entry point, includes all others |
| `ROMol.i` | Read-only molecule class |
| `RWMol.i` | Read-write molecule class |
| `Atom.i` | Atom class |
| `Bond.i` | Bond class |
| `MolOps.i` | Molecule operations |
| `SmilesParse.i` | SMILES parsing |
| `Fingerprints.i` | Fingerprint generation |
| `Descriptors.i` | Molecular descriptors |
| `MolDraw2D.i` | 2D drawing |

### Generated Files

| File | Description |
|------|-------------|
| `GraphMolRuby_wrap.cxx` | Generated C++ wrapper (22MB) |
| `GraphMolRuby_wrap.cxx.orig` | Backup before patching |

## Development Workflow

### Making Changes to Interface Files

1. Edit the `.i` file(s)
2. Regenerate wrapper: `rake swig:build`
3. Test build: `ruby ext/rdkit_chem/extconf.rb`
4. Commit both `.i` changes and new wrapper

### Updating SWIG Version

1. Install new SWIG version
2. Regenerate: `rake swig:build`
3. Test with multiple Ruby versions
4. Commit new wrapper

### Testing Wrapper Compatibility

```bash
# Test loading in different Ruby versions
rbenv shell 3.1.0 && ruby -e "require 'rdkit_chem'"
rbenv shell 3.2.0 && ruby -e "require 'rdkit_chem'"
rbenv shell 3.3.0 && ruby -e "require 'rdkit_chem'"
```

## Contact

For questions about the SWIG wrapper system, check:
1. This guide
2. `docs/pre-generated-swig-plan.md` (detailed implementation plan)
3. `tasks/swig.rake` (source code with comments)
