find_package(SWIG 4.2 REQUIRED)
include(${SWIG_USE_FILE})

INCLUDE_DIRECTORIES(${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${RDKit_CodeDir})
include_directories(${Boost_INCLUDE_DIRS})

SET(CMAKE_SWIG_FLAGS "")


set(swigRDKitLibSuffix "")
if(RDK_SWIG_STATIC AND ((NOT MSVC) OR (MSVC AND RDK_INSTALL_DLLS_MSVC)))
  set(swigRDKitLibSuffix "_static")
endif()
set(swigRDKitLibList "")
if(RDK_BUILD_AVALON_SUPPORT)
  set(swigRDKitLibList "${swigRDKitLibList}AvalonLib;avalon_clib;")
endif(RDK_BUILD_AVALON_SUPPORT)
if(RDK_BUILD_INCHI_SUPPORT)
  set(swigRDKitLibList "${swigRDKitLibList}RDInchiLib;${INCHI_LIBRARIES};")
endif(RDK_BUILD_INCHI_SUPPORT)
if(RDK_BUILD_CHEMDRAW_SUPPORT)
  set(swigRDKitLibList "${swigRDKitLibList}RDChemDrawLib;ChemDraw;")
endif(RDK_BUILD_CHEMDRAW_SUPPORT)
set(swigRDKitLibList "${swigRDKitLibList}"
  "RascalMCES;GeneralizedSubstruct;Abbreviations;ScaffoldNetwork;MolHash;RGroupDecomposition;SubstructLibrary;TautomerQuery;"
  "MolEnumerator;"
  "MolStandardize;FilterCatalog;Catalogs;FMCS;MolDraw2D;FileParsers;SmilesParse;MarvinParser;"
  "Depictor;SubstructMatch;ChemReactions;Fingerprints;ChemTransforms;"
  "Subgraphs;GraphMol;DataStructs;Trajectory;Descriptors;"
  "PartialCharges;MolTransforms;DistGeomHelpers;DistGeometry;"
  "ForceFieldHelpers;ForceField;EigenSolvers;Optimizer;MolAlign;O3AAlign;"
  "Alignment;SimDivPickers;RDGeometryLib;RDStreams;RDGeneral;"
)
#if(RDK_BUILD_COORDGEN_SUPPORT)
#  set(swigRDKitLibList "${swigRDKitLibList};${RDK_COORDGEN_LIBS}")
#endif(RDK_BUILD_COORDGEN_SUPPORT)
if(RDK_USE_URF)
  set(swigRDKitLibList "${swigRDKitLibList};${RDK_URF_LIBS};")
endif(RDK_USE_URF)
set(swigRDKitLibs "")
foreach(swigRDKitLib ${swigRDKitLibList})
  set(swigRDKitLibs "${swigRDKitLibs}${swigRDKitLib}${swigRDKitLibSuffix};")
endforeach()
set(swigRDKitLibs "${swigRDKitLibs}${Boost_SERIALIZATION_LIBRARY};")

if(RDK_USE_BOOST_IOSTREAMS)
ADD_DEFINITIONS("-DRDK_USE_BOOST_IOSTREAMS")

if(Boost_VERSION_STRING VERSION_LESS "1.86.0")
  set(_boost_iostreams_components system iostreams)
else()
  set(_boost_iostreams_components iostreams)
endif()

if(WIN32)
  find_package(Boost 1.56.0 COMPONENTS ${_boost_iostreams_components} REQUIRED)
  set(swigRDKitLibs "${swigRDKitLibs}${Boost_IOSTREAMS_LIBRARY};")
  if(Boost_SYSTEM_LIBRARY)
    set(swigRDKitLibs "${swigRDKitLibs}${Boost_SYSTEM_LIBRARY};")
  endif()

  find_package(Boost 1.56.0 COMPONENTS zlib)
  if(Boost_ZLIB_FOUND)
    set(swigRDKitLibs "${swigRDKitLibs}${Boost_ZLIB_LIBRARY};")
  endif()
else()
  find_package(Boost 1.56.0 COMPONENTS ${_boost_iostreams_components} REQUIRED)
  set(swigRDKitLibs "${swigRDKitLibs}${Boost_IOSTREAMS_LIBRARY};")
  if(Boost_SYSTEM_LIBRARY)
    set(swigRDKitLibs "${swigRDKitLibs}${Boost_SYSTEM_LIBRARY};")
  endif()
endif()
endif(RDK_USE_BOOST_IOSTREAMS)



set(RDKit_Wrapper_Libs ${swigRDKitLibs})

message("SUFFIX: ${swigRDKitLibSuffix}")
message("RUBY_LIBS: ${RDKit_Wrapper_Libs}")

add_subdirectory(gmwrapper)
