# macOS Build Notes for RDKit Ruby Extension

## Build Environment
- **Server:** macos (ssh alias)
- **Path:** `/Users/annguyenthanh/Projects/rdkit_chem`
- **Date:** January 21, 2025

## Issues Encountered and Solutions

### 1. Boost Serialization Not Found

**Error:**
```
CMake Error: Found package configuration file boost_serialization-config.cmake
but it set boost_serialization_FOUND to FALSE
Reason: No suitable build variant has been found.
* libboost_serialization.a (static runtime, Boost_USE_STATIC_RUNTIME not ON)
```

**Cause:** Boost was built with `runtime-link=static` but CMake wasn't configured to use static runtime libraries.

**Solution:** Added Boost static flags to `ext/rdkit_chem/extconf.rb`:
```ruby
'-DBoost_NO_BOOST_CMAKE=ON -DBoost_USE_STATIC_LIBS=ON -DBoost_USE_STATIC_RUNTIME=ON'
```

---

### 2. SWIG Preprocessing Error

**Error:**
```
GraphMolRuby.i:66: Error: Extraneous #endif.
```

**Cause:** Local modifications to `Code/RubyWrappers/gmwrapper/GraphMolRuby.i` had unbalanced `%{` `%}` SWIG directive blocks.

**Solution:** Restore the file to git version:
```bash
git checkout Code/RubyWrappers/gmwrapper/GraphMolRuby.i
```

---

### 3. Ruby Symbol Linking Error (macOS)

**Error:**
```
Undefined symbols for architecture x86_64:
  "_rb_define_class", "_rb_str_new", "_rb_ary_new", ... (hundreds of Ruby C API symbols)
ld: symbol(s) not found for architecture x86_64
```

**Cause:** On macOS, Ruby extensions should not link directly against Ruby library. Instead, symbols should be resolved at load time.

**Solution:** Added to `Code/RubyWrappers/gmwrapper/CMakeLists.txt`:
```cmake
# On macOS, Ruby extensions should use -undefined dynamic_lookup to allow
# Ruby symbols to be resolved at load time rather than link time
if(APPLE)
  set_target_properties(RDKitChem PROPERTIES
    LINK_FLAGS "-undefined dynamic_lookup")
endif()
```

---

### 4. Runtime Loading Error - "wrong argument type nil (expected Data)"

**Error:**
```ruby
require 'RDKitChem'
# => TypeError: wrong argument type nil (expected Data)
```

**Cause:** Ruby 3.2+ introduced a new `Data` class for immutable value objects. This conflicts with SWIG's internal use of Ruby's C-level `Data_Wrap_Struct` mechanism.

**Status:** UNRESOLVED with Ruby 3.3.7 and 3.4.8

**Workaround:** Use Ruby 3.1.x (does not have the new `Data` class)

```bash
asdf install ruby 3.1.6
asdf set ruby 3.1.6
```

Then rebuild:
```bash
rm -rf rdkit/build rdkit_chem
ruby ext/rdkit_chem/extconf.rb
```

---

### 5. GitHub Actions CI Failure - Xcode SDK Ruby Header Incompatibility

**Error:**
```
/Applications/Xcode_16.4.app/.../Ruby.framework/Headers/ruby/ruby/intern.h:56:19: 
error: ISO C++17 does not allow 'register' storage class specifier [-Wregister]

/Applications/Xcode_16.4.app/.../usr/include/c++/v1/__math/special_functions.h:51:8: 
error: no member named 'finite' in namespace 'std::__math'; did you mean simply 'finite'?
```

**Cause:** On GitHub Actions macOS runners, CMake's `find_package(Ruby)` picks up **system Ruby headers from Xcode SDK** instead of the Ruby installed by `ruby/setup-ruby`. The Xcode SDK Ruby headers:
1. Use deprecated `register` keyword (error in C++17)
2. Define `finite()` which pollutes namespace and breaks `std::isfinite`

**Why it works locally but fails in CI:**
| Environment | Ruby Headers Used | Result |
|-------------|-------------------|--------|
| Local macOS (Homebrew/rbenv/asdf) | User-installed Ruby headers | ✅ Works |
| GitHub Actions macOS | Xcode SDK Ruby headers | ❌ Fails |

**Solution:** Explicitly pass Ruby paths to CMake in `ext/rdkit_chem/extconf.rb`:
```ruby
ruby_executable = RbConfig.ruby
ruby_include_dir = RbConfig::CONFIG['rubyhdrdir']
ruby_arch_include_dir = RbConfig::CONFIG['rubyarchhdrdir']

extra_cmake_flags += " -DRuby_EXECUTABLE=#{ruby_executable}"
extra_cmake_flags += " -DRuby_INCLUDE_DIR=#{ruby_include_dir}"
extra_cmake_flags += " -DRuby_CONFIG_INCLUDE_DIR=#{ruby_arch_include_dir}"
extra_cmake_flags += " -DCMAKE_IGNORE_PREFIX_PATH='/Applications/Xcode.app;/Applications/Xcode_*.app'" if is_mac
```

This ensures CMake uses the correct Ruby installation rather than Xcode SDK headers.

---

## Build Commands

### Full Clean Build
```bash
cd /Users/annguyenthanh/Projects/rdkit_chem
source ~/.zshrc
rm -rf rdkit/build rdkit_chem
ruby ext/rdkit_chem/extconf.rb
```

### Resume Interrupted Build
```bash
cd /Users/annguyenthanh/Projects/rdkit_chem/rdkit/build
source ~/.zshrc
make -j8
make install
```

### Test Loading
```bash
cd /Users/annguyenthanh/Projects/rdkit_chem
DYLD_LIBRARY_PATH=$PWD/rdkit_chem/lib ruby -I $PWD/rdkit_chem/lib -e 'require "RDKitChem"; puts "Success!"'
```

---

## Files Modified

| File | Change |
|------|--------|
| `ext/rdkit_chem/extconf.rb` | Added Boost static flags, macOS C++ flags (`-Wno-register`, `-DHAVE_ISFINITE=1`), explicit Ruby path hints for CMake |
| `Code/RubyWrappers/gmwrapper/CMakeLists.txt` | Added `-undefined dynamic_lookup` for macOS |

---

## Ruby Version Compatibility

| Ruby Version | Build | Runtime | Notes |
|--------------|-------|---------|-------|
| 3.4.8 | ✅ | ❌ | `Data` class conflict |
| 3.3.7 | ✅ | ❌ | `Data` class conflict |
| 3.1.6 | ✅ | ⏳ | Testing in progress |

---

## Dependencies (macOS)

Installed via Homebrew:
- cmake
- swig (4.4.1)
- boost (1.84.0) - custom build in `boost_1_84_0_install/`
- freetype
- eigen

---

## Known Issues

1. **SWIG + Ruby 3.2+ Incompatibility**: The new `Data` class in Ruby 3.2+ conflicts with SWIG's wrapper generation. This is a known issue in the SWIG community. Potential solutions:
   - Use Ruby 3.1.x
   - Wait for SWIG update with Ruby 3.2+ Data class compatibility
   - Patch SWIG runtime to avoid conflict

2. **Build Time**: Full build takes ~20 minutes on the macOS server.

3. **Boost Warnings**: Some `BOOST_NO_CXX98_FUNCTION_BASE` macro redefinition warnings appear during build - these are harmless.

4. **GitHub Actions macOS CI**: Must explicitly specify Ruby paths to CMake to avoid Xcode SDK header conflicts. See Issue #5 above.

5. **Xcode 16+ Compatibility**: Newer Xcode versions bundle Ruby headers that are incompatible with C++17 compilation. The fix involves compiler flags (`-Wno-register`, `-DHAVE_ISFINITE=1`) and explicit Ruby path hints.
