
# rdkit-chem gem

GEM for [RDKIT](http://rdkit.org/), an Open-Source Cheminformatics Software

## Environment

### Prerequisites
  * cmake 3.8 or later
  * curl
  * tar, sed, make (those should be present anyway)
  * SWIG 2 or later
  * python header (`python-dev`)
  * sqlite (`sqlite3-dev`)
  * boost > 1.58 (`libboost-all-dev`)
  * gcc
  

## Install
`gem install rdkit_chem`

It downloads the sources, compiles and installs RDKIT with the ruby bindings.
The installation may last very long - please be patient.

## macOS Build Notes

### Known Issues and Solutions

#### 1. Boost Serialization Not Found

**Error:**
```
CMake Error: Found package configuration file boost_serialization-config.cmake
but it set boost_serialization_FOUND to FALSE
Reason: No suitable build variant has been found.
```

**Solution:** The gem has been updated to use static Boost flags (`-DBoost_USE_STATIC_LIBS=ON -DBoost_USE_STATIC_RUNTIME=ON`).

#### 2. Ruby Symbol Linking Error

**Error:**
```
Undefined symbols for architecture x86_64:
  "_rb_define_class", "_rb_str_new", ... (Ruby C API symbols)
```

**Solution:** Fixed in `Code/RubyWrappers/gmwrapper/CMakeLists.txt` with `-undefined dynamic_lookup` for macOS.

#### 3. Ruby 3.2+ Compatibility (CRITICAL)

**Error:**
```ruby
require 'RDKitChem'
# => TypeError: wrong argument type nil (expected Data)
```

**Cause:** Ruby 3.2+ introduced a new `Data` class that conflicts with SWIG's wrapper generation.

**Workaround:** Use Ruby 3.1.x:
```bash
# Using asdf
asdf install ruby 3.1.6
asdf set ruby 3.1.6

# Using rbenv
rbenv install 3.1.6
rbenv local 3.1.6
```

#### 4. GitHub Actions CI - Xcode SDK Header Conflict

**Error:**
```
error: ISO C++17 does not allow 'register' storage class specifier [-Wregister]
error: no member named 'finite' in namespace 'std::__math'
```

**Cause:** CMake finds Xcode SDK Ruby headers instead of `ruby/setup-ruby` installed headers.

**Solution:** Fixed in `extconf.rb` by explicitly passing Ruby paths to CMake.

### Ruby Version Compatibility

| Ruby Version | Build | Runtime | Notes |
|--------------|-------|---------|-------|
| 3.4.x | OK | FAIL | `Data` class conflict |
| 3.3.x | OK | FAIL | `Data` class conflict |
| 3.2.x | OK | FAIL | `Data` class conflict |
| 3.1.x | OK | OK | Recommended |

### Build Commands (macOS)

**Full Clean Build:**
```bash
rm -rf rdkit/build rdkit_chem
ruby ext/rdkit_chem/extconf.rb
```

**Resume Interrupted Build:**
```bash
cd rdkit/build
make -j8
make install
```

**Test Loading:**
```bash
DYLD_LIBRARY_PATH=$PWD/rdkit_chem/lib ruby -I $PWD/rdkit_chem/lib -e 'require "RDKitChem"; puts "Success!"'
```

### Additional Notes

- Full build takes ~20 minutes
- Some `BOOST_NO_CXX98_FUNCTION_BASE` warnings during build are harmless
- For detailed troubleshooting, see [MACOS_BUILD_NOTES.md](MACOS_BUILD_NOTES.md)
