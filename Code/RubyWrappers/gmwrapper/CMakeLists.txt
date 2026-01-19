cmake_minimum_required(VERSION 3.8)

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

if(APPLE)
  set_target_properties(RDKitChem PROPERTIES
    LINK_FLAGS "-undefined dynamic_lookup"
    SUFFIX ".bundle")
endif()

# it doesnt seem like the threading libs should need to be here, but
# as of Oct 2012 using boost 1.51 under at least ubuntu 12.04 we get a
# link error if they aren't there.
SWIG_LINK_LIBRARIES(RDKitChem
  ${RDKit_Wrapper_Libs}
  ${Boost_SERIALIZATION_LIBRARY}
  ${RDKit_THREAD_LIBS})

MESSAGE("serial: ${Boost_SERIALIZATION_LIBRARY}")
MESSAGE("THREAD: ${RDKit_THREAD_LIBS}")

INSTALL(TARGETS RDKitChem LIBRARY DESTINATION lib)
