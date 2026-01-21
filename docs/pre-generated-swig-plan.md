# Pre-Generated SWIG Wrapper Implementation Plan

## Executive Summary

This document outlines the plan to implement pre-generated SWIG wrappers for rdkit_chem, eliminating the need for SWIG at build time while enabling Ruby 3.2+ compatibility through post-generation patching.

## Current Architecture

### Build Flow (Current)
```
GraphMolRuby.i ──┐
     │          │
     ▼          │
  %include ─────┴──▶ 70+ .i files
     │
     ▼
[CMake SWIG_ADD_LIBRARY]
     │
     ▼
GraphMolRubyRUBY_wrap.cxx (generated at build time)
     │
     ▼
RDKitChem.so / RDKitChem.bundle
```

### Key Files
| File | Purpose |
|------|---------|
| `Code/RubyWrappers/gmwrapper/GraphMolRuby.i` | Main SWIG entry point (includes all others) |
| `Code/RubyWrappers/*.i` | 70+ module interface files |
| `Code/RubyWrappers/gmwrapper/CMakeLists.txt` | CMake SWIG configuration |
| `Code/RubyWrappers/CMakeLists.txt` | Library linking configuration |

### Current SWIG Configuration
- **SWIG Version**: 4.2+ required
- **Flags**: `-small -naturalvar -autorename`
- **Conditional Flags**: `-DRDK_BUILD_INCHI_SUPPORT`, `-DRDK_BUILD_AVALON_SUPPORT`, `-DRDK_USE_BOOST_IOSTREAMS`
- **Output**: Single monolithic wrapper file

### Problems with Current Approach
1. **SWIG Required at Build Time**: Users must have SWIG 4.2+ installed
2. **Ruby 3.2+ Incompatibility**: SWIG generates code using `Data` class, which conflicts with Ruby's new `Data` class
3. **Build Time**: SWIG processing adds to already long compile times
4. **Reproducibility**: Different SWIG versions may produce different output

---

## Proposed Architecture

### Build Flow (Proposed)
```
GraphMolRuby.i ──┐
     │          │
     ▼          │
  %include ─────┴──▶ 70+ .i files
     │
     ▼
[rake swig:generate] (dev machine, requires SWIG)
     │
     ▼
GraphMolRuby_wrap.cxx (pre-generated, committed to repo)
     │
     ▼
[rake swig:patch] (apply Ruby 3.2+ fixes)
     │
     ▼
GraphMolRuby_wrap.cxx (patched, ready for compilation)
     │
     ▼
[CMake compile only] (no SWIG needed)
     │
     ▼
RDKitChem.so / RDKitChem.bundle
```

### File Structure Changes
```
Code/RubyWrappers/
├── gmwrapper/
│   ├── GraphMolRuby.i              # Source (maintained)
│   ├── GraphMolRuby_wrap.cxx       # Pre-generated (committed)
│   └── CMakeLists.txt              # Modified to use pre-generated
├── *.i                              # 70+ interface files (unchanged)
└── CMakeLists.txt                   # Unchanged

tasks/
└── swig.rake                        # New: SWIG generation tasks

Rakefile                             # Modified: load tasks/swig.rake
```

---

## Implementation Phases

### Phase 1: Create SWIG Rake Tasks

**File**: `tasks/swig.rake`

**Tasks**:

| Task | Description | Requires SWIG |
|------|-------------|---------------|
| `swig:generate` | Generate wrapper from .i files | Yes |
| `swig:patch` | Apply Ruby 3.2+ compatibility fixes | No |
| `swig:clean` | Remove generated wrapper | No |
| `swig:status` | Check if wrapper exists and is patched | No |

**Generator Logic**:
```ruby
# Equivalent to what CMake does:
swig -c++ -ruby \
  -small -naturalvar -autorename \
  -I#{rdkit_include_dir} \
  -I#{boost_include_dir} \
  -I#{ruby_wrappers_dir} \
  -DRDK_BUILD_INCHI_SUPPORT \      # if enabled
  -DRDK_BUILD_AVALON_SUPPORT \     # if enabled
  -DRDK_USE_BOOST_IOSTREAMS \      # if enabled
  -o GraphMolRuby_wrap.cxx \
  GraphMolRuby.i
```

**Patch Logic** (Ruby 3.2+ fix):
```ruby
# The issue: SWIG generates code that uses Ruby's 'Data' class
# Ruby 3.2+ introduced a new Data class that conflicts
#
# Fix: Rename SWIG's Data usage to SWIG_Data or similar
# Key patterns to replace:
#   - rb_cData -> rb_cSwigData
#   - "Data" class definitions -> "SwigData"
```

### Phase 2: Modify CMakeLists.txt

**File**: `Code/RubyWrappers/gmwrapper/CMakeLists.txt`

**Changes**:
1. Check if pre-generated wrapper exists
2. If exists, use it directly (skip SWIG)
3. If not exists, fall back to SWIG generation (development mode)

**Logic**:
```cmake
set(WRAPPER_FILE "${CMAKE_CURRENT_SOURCE_DIR}/GraphMolRuby_wrap.cxx")

if(EXISTS ${WRAPPER_FILE} AND NOT FORCE_SWIG_GENERATION)
  message(STATUS "Using pre-generated SWIG wrapper")
  # Add wrapper as source directly
  add_library(RDKitChem MODULE ${WRAPPER_FILE})
else()
  message(STATUS "Generating SWIG wrapper (SWIG required)")
  # Existing SWIG_ADD_LIBRARY logic
  SWIG_ADD_LIBRARY(RDKitChem TYPE MODULE LANGUAGE ruby SOURCES GraphMolRuby.i)
endif()
```

### Phase 3: Generate Initial Wrapper

**Environment**: macOS server (ssh macos)
- SWIG 4.4.1 installed
- RDKit source available
- Ruby 4.0.1 (for headers)

**Steps**:
1. Configure RDKit build to get include paths
2. Run SWIG manually with correct flags
3. Apply Ruby 3.2+ patches
4. Commit wrapper to repo

### Phase 4: Ruby 3.2+ Compatibility Patch

**The Problem**:
Ruby 3.2 introduced `Data` as a core class (previously it was internal). SWIG-generated code uses `Data` for wrapping C++ pointers, causing conflicts.

**The Solution**:
Patch the generated wrapper to avoid conflicts. Key changes:

```cpp
// Before (SWIG generated)
VALUE rb_cData;
rb_define_class("Data", rb_cObject);

// After (patched)
VALUE rb_cSwigData;
rb_define_class("SwigData", rb_cObject);
```

**Comprehensive Patch Targets**:
1. `rb_cData` variable references
2. Class definitions using "Data" name
3. Type checking macros
4. Inheritance chains referencing Data

**Patch Script** (in swig.rake):
```ruby
def patch_ruby32_compatibility(wrapper_file)
  content = File.read(wrapper_file)
  
  # Track if we made changes
  original = content.dup
  
  # Pattern 1: Variable renaming
  content.gsub!(/\brb_cData\b/, 'rb_cSwigData')
  
  # Pattern 2: Class definition strings
  content.gsub!(/"Data"/, '"SwigData"')
  
  # Pattern 3: Type checking (if any)
  content.gsub!(/TYPE_DATA/, 'TYPE_SWIG_DATA')
  
  if content != original
    File.write(wrapper_file, content)
    puts "Applied Ruby 3.2+ compatibility patch"
    true
  else
    puts "No patching needed"
    false
  end
end
```

---

## Detailed Implementation Steps

### Step 1: Create tasks/swig.rake

```ruby
# tasks/swig.rake

namespace :swig do
  WRAPPER_DIR = 'Code/RubyWrappers/gmwrapper'
  WRAPPER_FILE = "#{WRAPPER_DIR}/GraphMolRuby_wrap.cxx"
  INTERFACE_FILE = "#{WRAPPER_DIR}/GraphMolRuby.i"
  
  desc 'Generate SWIG wrapper from interface files'
  task :generate do
    # Implementation
  end
  
  desc 'Apply Ruby 3.2+ compatibility patches'
  task :patch do
    # Implementation
  end
  
  desc 'Generate and patch in one step'
  task :build => [:generate, :patch]
  
  desc 'Remove generated wrapper'
  task :clean do
    FileUtils.rm_f(WRAPPER_FILE)
  end
  
  desc 'Check wrapper status'
  task :status do
    # Implementation
  end
end
```

### Step 2: Update Rakefile

Add to Rakefile:
```ruby
# Load additional tasks
Dir.glob('tasks/**/*.rake').each { |r| load r }
```

### Step 3: Modify CMakeLists.txt

Add pre-generated wrapper support while maintaining backward compatibility.

### Step 4: Generate and Commit Wrapper

On macOS:
```bash
ssh macos
cd /path/to/rdkit_chem
rake swig:build
git add Code/RubyWrappers/gmwrapper/GraphMolRuby_wrap.cxx
git commit -m "Add pre-generated SWIG wrapper with Ruby 3.2+ patch"
```

---

## Testing Plan

### Test 1: Build Without SWIG
```bash
# Ensure SWIG is not in PATH
export PATH=/usr/bin:/bin
cd rdkit_chem
ruby ext/rdkit_chem/extconf.rb
# Should succeed using pre-generated wrapper
```

### Test 2: Ruby 3.2+ Loading
```bash
# With Ruby 3.2+
ruby -e "require 'rdkit_chem'; puts 'Success'"
# Should not raise Data class conflict
```

### Test 3: Regeneration
```bash
# With SWIG installed
rake swig:build
# Should produce identical (or compatible) wrapper
```

### Test 4: Full Test Suite
```bash
rake test
# All tests should pass
```

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| SWIG version differences | Generated code may vary | Pin SWIG version in CI, document required version |
| Patch breaks functionality | Runtime errors | Comprehensive test suite, gradual rollout |
| Large committed file (~1-2MB) | Repo bloat | Acceptable trade-off for build simplicity |
| Conditional compilation flags | Different builds need different wrappers | Generate "full" wrapper with all features, use runtime checks |

---

## Rollback Plan

If issues arise:
1. Delete `GraphMolRuby_wrap.cxx`
2. Revert CMakeLists.txt changes
3. Build will fall back to SWIG generation

---

## Timeline

| Phase | Task | Duration |
|-------|------|----------|
| 1 | Create tasks/swig.rake | 1 hour |
| 2 | Modify CMakeLists.txt | 30 min |
| 3 | Generate initial wrapper on macOS | 1 hour |
| 4 | Apply and test Ruby 3.2+ patch | 2 hours |
| 5 | Testing across Ruby versions | 2 hours |
| **Total** | | **~6.5 hours** |

---

## Appendix A: SWIG Flags Reference

| Flag | Purpose |
|------|---------|
| `-c++` | Enable C++ mode |
| `-ruby` | Generate Ruby bindings |
| `-small` | Reduce generated code size |
| `-naturalvar` | More natural variable access |
| `-autorename` | Auto-rename methods to Ruby conventions |
| `-DRDK_BUILD_INCHI_SUPPORT` | Enable InChI support |
| `-DRDK_BUILD_AVALON_SUPPORT` | Enable Avalon support |
| `-DRDK_USE_BOOST_IOSTREAMS` | Enable Boost iostreams |

## Appendix B: Include Paths Required

```
-I${RDKIT_SOURCE}/Code
-I${RDKIT_SOURCE}/External
-I${BOOST_INCLUDE_DIR}
-I${RUBY_INCLUDE_DIR}
-I${RUBY_ARCH_INCLUDE_DIR}
```

## Appendix C: Expected Wrapper Size

Based on similar projects:
- **taglib-ruby**: ~500KB per module, ~2MB total
- **rdkit_chem estimate**: 1-3MB (single monolithic wrapper)

This is acceptable for the benefits gained.
