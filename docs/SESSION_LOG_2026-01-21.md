# Session Log: Pre-Generated SWIG Wrapper Implementation

**Date**: January 21, 2026  
**Goal**: Implement pre-generated SWIG wrappers for rdkit_chem to eliminate SWIG dependency at build time

## Background

rdkit_chem is a Ruby gem that provides bindings to the RDKit cheminformatics library. Previously, building the gem required SWIG to generate C++ wrapper code from `.i` interface files at build time.

### Problems with Previous Approach
1. Users need SWIG 4.2+ installed
2. SWIG generation adds to already long build time (~20 min)
3. Ruby 3.2+ introduced a `Data` class that conflicts with SWIG-generated code
4. Different SWIG versions may produce different output

## What We Did

### Phase 1: Analysis

1. **Examined taglib-ruby** for reference (similar SWIG-based Ruby binding)
   - Uses Rake-based build with pre-generated wrappers
   - Modular design with separate extensions
   - Successfully compiled on macOS as proof-of-concept

2. **Analyzed rdkit_chem structure**
   - 72 `.i` interface files in `Code/RubyWrappers/`
   - Single monolithic entry point: `GraphMolRuby.i`
   - CMake-based build (different from taglib-ruby's Rake)
   - Current SWIG 4.2 requirement

### Phase 2: Implementation

#### Created `docs/pre-generated-swig-plan.md`
Detailed implementation plan with:
- Architecture diagrams
- Phase-by-phase steps
- Risk assessment
- Rollback plan

#### Created `tasks/swig.rake`
Rake tasks for SWIG wrapper management:
```ruby
rake swig:generate   # Generate wrapper
rake swig:patch      # Apply Ruby 3.2+ fixes
rake swig:build      # Generate + patch
rake swig:clean      # Remove wrapper
rake swig:status     # Check status
rake swig:check      # Verify prerequisites
rake swig:dry_run    # Show command
```

Key features:
- Auto-detects RDKit/Boost/Ruby include paths
- Supports environment variable overrides
- Ruby 3.2+ compatibility patching
- Verbose mode for debugging

#### Updated `Rakefile`
Added task loading:
```ruby
Dir.glob('tasks/**/*.rake').each { |r| load r }
```

#### Updated `Code/RubyWrappers/gmwrapper/CMakeLists.txt`
Added pre-generated wrapper support:
- `USE_PREGENERATED_SWIG` option (auto-detected)
- `FORCE_SWIG_GENERATION` option for dev override
- Falls back to SWIG generation if wrapper missing

### Phase 3: Wrapper Generation

#### Environment (macOS Server)
- macOS 15.7.3 (Sequoia), Intel x86_64
- SWIG 4.4.1 (`/usr/local/bin/swig`)
- Ruby 4.0.1 (`/usr/local/opt/ruby/bin/ruby`)
- Boost headers (`/usr/local/include`)

#### Challenges Encountered

1. **RDKit headers not available**
   - Solution: Used headers from previous rdkit_chem build (`rdkit_chem/include/rdkit/`)

2. **Relative include paths in .i files**
   - Files use `../RDGeneral/Dict.h` relative to `Code/RubyWrappers/`
   - Solution: Created symlinks in `Code/` pointing to installed headers

3. **GenericRDKitException.h not found**
   - Included as `RubyWrappers/GenericRDKitException.h`
   - Solution: Added `Code/` directory to include paths

#### Final SWIG Command
```bash
/usr/local/bin/swig -c++ -ruby -small -naturalvar -autorename \
  -ICode/RubyWrappers \
  -Irdkit_chem/include/rdkit \
  -Irdkit_chem/include \
  -ICode \
  -I/usr/local/include \
  -I/usr/local/Cellar/ruby/4.0.1/include/ruby-4.0.0 \
  -I/usr/local/Cellar/ruby/4.0.1/include/ruby-4.0.0/x86_64-darwin23 \
  -o Code/RubyWrappers/gmwrapper/GraphMolRuby_wrap.cxx \
  Code/RubyWrappers/gmwrapper/GraphMolRuby.i
```

#### Result
- Generated `GraphMolRuby_wrap.cxx`: **22.32 MB**
- Many warnings (expected for complex C++ code)
- No errors

### Phase 4: Ruby 3.2+ Compatibility Check

**Finding**: SWIG 4.4.1 does NOT generate the `rb_cData` conflict pattern!

Searched for patterns:
- `rb_cData`: 0 occurrences
- `"Data"` class definitions: 0 occurrences

The wrapper uses `Data_Wrap_Struct` (Ruby C API macro) which is fine - it's not the `Data` class itself.

**Conclusion**: No patching needed with current SWIG version. The `rake swig:patch` task exists for future compatibility if issues arise.

## Files Changed

| File | Change |
|------|--------|
| `docs/pre-generated-swig-plan.md` | Created - Detailed plan |
| `docs/SWIG_WRAPPER_GUIDE.md` | Created - User guide |
| `docs/SESSION_LOG_2026-01-21.md` | Created - This file |
| `tasks/swig.rake` | Created - Rake tasks |
| `Rakefile` | Modified - Load tasks |
| `Code/RubyWrappers/gmwrapper/CMakeLists.txt` | Modified - Pre-generated support |
| `Code/RubyWrappers/gmwrapper/GraphMolRuby_wrap.cxx` | Generated - 22MB wrapper |

## Testing Notes

### To Test Build Without SWIG
```bash
# Ensure wrapper exists
ls -la Code/RubyWrappers/gmwrapper/GraphMolRuby_wrap.cxx

# Remove SWIG from PATH
export PATH=/usr/bin:/bin

# Build should succeed using pre-generated wrapper
ruby ext/rdkit_chem/extconf.rb
```

### To Test Ruby 3.2+ Compatibility
```bash
# Use Ruby 3.2+
rbenv shell 3.2.0  # or asdf shell ruby 3.2.0

# Build and test
ruby ext/rdkit_chem/extconf.rb
ruby -e "require 'rdkit_chem'; puts 'Success!'"
```

### To Regenerate Wrapper
```bash
# On macOS with SWIG installed
rake swig:build

# Or manually
export RDKIT_INCLUDE_DIR=/path/to/rdkit/headers
rake swig:generate
```

## Known Issues

1. **Wrapper file is large (22MB)**
   - Consider Git LFS for storage
   - Or generate on CI instead of committing

2. **Symlinks needed for generation**
   - When regenerating, need symlinks from `Code/` to installed headers
   - The rake task handles this automatically if headers are in expected locations

3. **RuboCop warnings in swig.rake**
   - Metrics/BlockLength warnings (namespace block is large)
   - Constants defined in block (intentional for rake namespace)
   - These don't affect functionality

## Next Steps

1. **Test full build cycle** on macOS and Linux
2. **Test with Ruby 3.2+** to confirm compatibility
3. **Decide on wrapper storage**:
   - Commit to repo (large file)
   - Use Git LFS
   - Generate on CI
4. **Update README** with new build instructions
5. **Consider CI integration** for automated wrapper regeneration

## Commands Reference

```bash
# Check status
rake swig:status

# Regenerate wrapper
rake swig:build

# Force CMake to use SWIG
cmake ... -DFORCE_SWIG_GENERATION=ON

# Use pre-generated wrapper (default)
cmake ... -DUSE_PREGENERATED_SWIG=ON
```

## Contact

Session performed by AI assistant. Documentation created for knowledge transfer.
