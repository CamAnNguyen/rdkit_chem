cmake_minimum_required(VERSION 3.18)

# Apple: Don't modify install_name when touching RPATH.
if(POLICY CMP0068)
  cmake_policy(SET CMP0068 NEW)
endif()
# target_sources: use absolute path for INTERFACE_SOURCES.
if(POLICY CMP0076)
  cmake_policy(SET CMP0076 NEW)
endif()
# SWIG: use standard target name.
if(POLICY CMP0078)
  cmake_policy(SET CMP0078 NEW)
endif()
# SWIG: use SWIG_MODULE_NAME property.
if(POLICY CMP0086)
  cmake_policy(SET CMP0086 NEW)
endif()

project (GraphMolRuby)

include_directories( ${RDKit_ExternalDir} )

find_package(Ruby REQUIRED)

INCLUDE_DIRECTORIES(${RDKit_INCLUDE_DIR} ${RUBY_INCLUDE_PATH})

if(APPLE)
  add_compile_options(-Wno-register -include ${CMAKE_CURRENT_SOURCE_DIR}/ruby_compat.h)
endif()

SET_SOURCE_FILES_PROPERTIES(GraphMolRuby.i PROPERTIES CPLUSPLUS ON )

SET(CMAKE_SWIG_OUTDIR ${CMAKE_CURRENT_SOURCE_DIR}/swig_ruby )

if(RDK_BUILD_INCHI_SUPPORT)
  SET(CMAKE_SWIG_FLAGS "-DRDK_BUILD_INCHI_SUPPORT" ${CMAKE_SWIG_FLAGS} )
endif()
if(RDK_BUILD_AVALON_SUPPORT)
  SET(CMAKE_SWIG_FLAGS "-DRDK_BUILD_AVALON_SUPPORT" ${CMAKE_SWIG_FLAGS} )
endif()
if(RDK_USE_BOOST_IOSTREAMS)
  SET(CMAKE_SWIG_FLAGS "-DRDK_USE_BOOST_IOSTREAMS" ${CMAKE_SWIG_FLAGS} )
endif()

FILE(GLOB SWIG_SRC_FILES "${CMAKE_CURRENT_SOURCE_DIR}/../*.i")

# we added all source files, now remove the ones that we're not supporting in this build:
if(NOT RDK_BUILD_AVALON_SUPPORT)
LIST(REMOVE_ITEM SWIG_SRC_FILES "${CMAKE_CURRENT_SOURCE_DIR}/../AvalonLib.i")
endif()

if(NOT RDK_BUILD_INCHI_SUPPORT)
LIST(REMOVE_ITEM SWIG_SRC_FILES "${CMAKE_CURRENT_SOURCE_DIR}/../Inchi.i")
endif()

SET(SWIG_MODULE_RDKitChem_EXTRA_DEPS ${SWIG_SRC_FILES} )
SET(CMAKE_SWIG_FLAGS -small -naturalvar -autorename)

SWIG_ADD_LIBRARY(RDKitChem TYPE MODULE LANGUAGE ruby SOURCES GraphMolRuby.i)

# Ensure all SWIG type information uses the same type table
# This is critical for macOS where symbol visibility differs from Linux
target_compile_definitions(RDKitChem PRIVATE SWIG_TYPE_TABLE=RDKitChem)

# it doesnt seem like the threading libs should need to be here, but
# as of Oct 2012 using boost 1.51 under at least ubuntu 12.04 we get a
# link error if they aren't there.
SWIG_LINK_LIBRARIES(RDKitChem
  ${RDKit_Wrapper_Libs}
  ${Boost_SERIALIZATION_LIBRARY}
  ${RDKit_THREAD_LIBS})

if(APPLE)
  # Ensure all symbols are visible (required for SWIG type system)
  target_compile_options(RDKitChem PRIVATE -fvisibility=default)

  # SWIG_GLOBAL forces the SWIG runtime to use a truly global type table
  # instead of looking it up through Ruby's global variable mechanism
  target_compile_definitions(RDKitChem PRIVATE SWIG_GLOBAL)

  # macOS linker flags:
  # -undefined dynamic_lookup: Allow undefined Ruby symbols, resolved at runtime
  target_link_options(RDKitChem PRIVATE
    "LINKER:-undefined,dynamic_lookup"
  )
  MESSAGE(STATUS "macOS: Using -undefined dynamic_lookup with SWIG_GLOBAL")
endif()

MESSAGE("serial: ${Boost_SERIALIZATION_LIBRARY}")
MESSAGE("THREAD: ${RDKit_THREAD_LIBS}")

INSTALL(TARGETS RDKitChem LIBRARY DESTINATION lib)
