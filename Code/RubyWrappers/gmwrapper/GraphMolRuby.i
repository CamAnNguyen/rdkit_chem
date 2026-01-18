/*
*
*  Copyright (c) 2010, Novartis Institutes for BioMedical Research Inc.
*  All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are
* met:
*
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above
*       copyright notice, this list of conditions and the following
*       disclaimer in the documentation and/or other materials provided
*       with the distribution.
*     * Neither the name of Novartis Institutes for BioMedical Research Inc.
*       nor the names of its contributors may be used to endorse or promote
*       products derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
* A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
* LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
* DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
* THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
* OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
%module RDKitChem



#if defined(SWIGWORDSIZE64)
%{
// There's a problem with SWIG, 64bit windows, and modern VC++ versions
//   This fine, fine piece of code fixes that.
//   it's ok to think this is horrible, we won't mind
#ifdef _MSC_VER

#ifndef LONG_MAX
#include <limits.h>
#endif

#if LONG_MAX==INT_MAX
#define LONG_MAX (INT_MAX+1)
#endif

#endif
%}
#endif

/* Suppress the unimportant warnings */
#pragma SWIG nowarn=503,516

// Ignore ostream operators globally - they cause redefinition errors and aren't useful in Ruby
%ignore operator<<;

%include <boost_shared_ptr.i>
%{
    #include <boost/shared_ptr.hpp>
    #include <boost/shared_array.hpp>
    #include <ForceField/UFF/Params.h>
%}
// The actual definition isn't in the top level hpp file!
// The next two lines are to work around a problem caused by the fact that older versions of
// SWIG don't work with newer versions of boost.
#define BOOST_SP_NOEXCEPT
#define BOOST_SP_NOEXCEPT_WITH_ASSERT
#define BOOST_NOEXCEPT
#define BOOST_NO_CXX11_RVALUE_REFERENCES
#define BOOST_NO_CXX11_NULLPTR
%include <boost/smart_ptr/shared_array.hpp>

/* undefine RDKIT_<LIBNAME>_EXPORT macros */
%include <RDGeneral/RDExportMacros.h>
%include <RDGeneral/export.h>
/* Include the base types before anything that will utilize them */
#ifdef SWIGWIN
%include "../msvc_stdint.i"
#else
%include "../stdint.i"
#endif

%include "std_string.i"
%include "std_list.i"
%include "extend_std_vector.i"
%include <std_map.i>
%include "std_pair.i"
%include "carrays.i"

/*
 * Custom handler for longs.  The problem is described in swig-Bugs-2965875
 * and most of this solution is taken from the proposed patch in that bug report.
 * -------------------------------------------------------------------------
 * Define typemaps for `long`
 *
 * This is complicated by the fact `long` is 32-bits on some platforms
 * but is 64-bits on other platforms. We're just going to override the
 * important ones here.
 */
#if defined(SWIGWORDSIZE64)
typedef long long int		int64_t;
typedef unsigned long long int	uint64_t;
typedef long long int		int_least64_t;
typedef unsigned long long int	uint_least64_t;
typedef long long int		int_fast64_t;
typedef unsigned long long int	uint_fast64_t;
typedef long long int		intmax_t;
typedef unsigned long long int	uintmax_t;

%apply long long { long };
%apply const long long & { const long & };
%apply unsigned long long { unsigned long };
%apply const unsigned long long & { const unsigned long & };

/*
#elif defined(SWIGWORDSIZE32)
%apply int { long };
%apply const int & { const long & };
%apply unsigned int { unsigned long };
%apply const unsigned int & { const unsigned long & };
#else
#error "Neither SWIGWORDSIZE64 nor SWIGWORDSIZE32 is defined"
*/

#endif

// Tell SWIG that boost and std integer types are equivalent to standard types
// This prevents duplicate swig::traits definitions
%apply int { boost::int32_t };
%apply const int & { const boost::int32_t & };
%apply unsigned int { boost::uint32_t };
%apply const unsigned int & { const boost::uint32_t & };
%apply int { std::int32_t };
%apply const int & { const std::int32_t & };
%apply unsigned int { std::uint32_t };
%apply const unsigned int & { const std::uint32_t & };

%shared_ptr(std::exception)
%shared_ptr(RDKit::RDProps)
%shared_ptr(RDKit::Conformer)
%shared_ptr(RDKit::ROMol)
%shared_ptr(RDKit::RWMol)
%shared_ptr(RDKit::Atom)
%shared_ptr(RDKit::Bond)
%shared_ptr(RDKit::PeriodicTable)
%shared_ptr(Canon::MolStackElem)
%shared_ptr(RDKit::QueryAtom)
%shared_ptr(RDKit::QueryBond)
%shared_ptr(RDKit::QueryOps)
%shared_ptr(RDKit::MolBundle)
%shared_ptr(RDKit::FixedMolSizeMolBundle)
%shared_ptr(RDKit::MolSanitizeException)
%shared_ptr(RDKit::AtomSanitizeException)
%shared_ptr(RDKit::AtomValenceException)
%shared_ptr(RDKit::AtomKekulizeException)
%shared_ptr(RDKit::KekulizeException)
%shared_ptr(RDKit::SmilesParseException)
%shared_ptr(RDKit::MolPicklerException)
%shared_ptr(RDKit::RingInfo)
%shared_ptr(RDKit::ChemicalReaction)
%shared_ptr(ForceFields::ForceFieldContrib);
%shared_ptr(ForceFields::UFF::AngleBendContrib);
%shared_ptr(ForceFields::UFF::BondStretchContrib);
%shared_ptr(ForceFields::DistanceConstraintContrib);
%shared_ptr(ForceFields::UFF::vdWContrib);
%shared_ptr(ForceFields::UFF::TorsionAngleContrib);
%shared_ptr(ForceFields::UFF::InversionContrib);
%shared_ptr(RDKit::FilterCatalogEntry);

/* http://swig.10945.n7.nabble.com/std-containers-and-pointers-td3728.html */
%{
  /* template <> struct swig::traits<RDKit::ROMol> { */
  /*   typedef pointer_category category; */
  /*   static const char* type_name() */
  /*   { */
  /*     return "ROMol"; */
  /*   } */
  /* }; */

  /* template <> struct swig::traits<ForceFields::UFF::AtomicParams> { */
  /*   typedef pointer_category category; */
  /*   static const char* type_name() */
  /*   { */
  /*     return "AtomicParams"; */
  /*   } */
  /* }; */
%}

/* Some utility classes for passing arrays in and out */
%array_class(double, Double_Array);

/* Since documentation management is deprecated in SWIG 1.3, we're using the suggested workarounds.  Apply them
   here so that can be removed easily later */
// Documentation

// Create a class to throw various sorts of errors for testing.  Required for unit tests in ErrorHandlingTests.java
/* #ifdef INCLUDE_ERROR_GENERATOR */
/* %include "../ErrorGenerator.i" */
/* #endif */

// Fixes annoying compilation namespace issue
typedef RDKit::MatchVectType MatchVectType;

%define VVTEMPLATE_WRAP(name, T)
%feature("ignore") std::vector< std::vector<T> >::append;
%feature("ignore") std::vector< std::vector<T> >::assign;
%feature("ignore") std::vector< std::vector<T> >::back;
%feature("ignore") std::vector< std::vector<T> >::begin;
%feature("ignore") std::vector< std::vector<T> >::capacity;
%feature("ignore") std::vector< std::vector<T> >::clear;
%feature("ignore") std::vector< std::vector<T> >::empty;
%feature("ignore") std::vector< std::vector<T> >::end;
%feature("ignore") std::vector< std::vector<T> >::equals;
%feature("ignore") std::vector< std::vector<T> >::erase;
%feature("ignore") std::vector< std::vector<T> >::front;
%feature("ignore") std::vector< std::vector<T> >::get_allocator;
%feature("ignore") std::vector< std::vector<T> >::insert;
%feature("ignore") std::vector< std::vector<T> >::pop;
%feature("ignore") std::vector< std::vector<T> >::pop_back;
%feature("ignore") std::vector< std::vector<T> >::push_back;
%feature("ignore") std::vector< std::vector<T> >::rbegin;
%feature("ignore") std::vector< std::vector<T> >::rend;
%feature("ignore") std::vector< std::vector<T> >::reserve;
%feature("ignore") std::vector< std::vector<T> >::resize;
%feature("ignore") std::vector< std::vector<T> >::size;
%feature("ignore") std::vector< std::vector<T> >::shift;
%feature("ignore") std::vector< std::vector<T> >::swap;
%feature("ignore") std::vector< std::vector<T> >::unshift;
%template(name ## VectVect) std::vector< std::vector<T> >;
%enddef

%define VECTORTEMPLATE_WRAP(vectorname, T)
%feature("ignore") std::vector<T>::append;
%feature("ignore") std::vector<T>::assign;
%feature("ignore") std::vector<T>::back;
%feature("ignore") std::vector<T>::begin;
%feature("ignore") std::vector<T>::capacity;
%feature("ignore") std::vector<T>::clear;
%feature("ignore") std::vector<T>::empty;
%feature("ignore") std::vector<T>::end;
%feature("ignore") std::vector<T>::erase;
%feature("ignore") std::vector<T>::equals;
%feature("ignore") std::vector<T>::front;
%feature("ignore") std::vector<T>::get_allocator;
%feature("ignore") std::vector<T>::insert;
%feature("ignore") std::vector<T>::pop;
%feature("ignore") std::vector<T>::pop_back;
%feature("ignore") std::vector<T>::push_back;
%feature("ignore") std::vector<T>::rbegin;
%feature("ignore") std::vector<T>::rend;
%feature("ignore") std::vector<T>::reserve;
%feature("ignore") std::vector<T>::resize;
%feature("ignore") std::vector<T>::size;
%feature("ignore") std::vector<T>::shift;
%feature("ignore") std::vector<T>::swap;
%feature("ignore") std::vector<T>::unshift;
%template(vectorname ## Vect) std::vector<T>;
%enddef

// DiceSimilarity template is instantiated in MorganFingerprints.i after SparseIntVect.h is included

/* vector */
%template(Int_Vect) std::vector<int>;
%template(Byte_Vect) std::vector<signed char>;
%template(Double_Vect) std::vector<double>;
// Use base types (unsigned int) to avoid duplicate swig::traits definitions
%template(UInt_Vect) std::vector<unsigned int>;
%template(Str_Vect)  std::vector<std::string>;
// Point vector templates removed - Ruby SWIG lacks swig::traits for custom types
// %template(Point_Vect) std::vector<RDGeom::Point *>;
// %template(Point2D_Vect) std::vector<RDGeom::Point2D *>;
// %template(Point3D_Vect) std::vector<RDGeom::Point3D *>;
// %template(Atomic_Params_Vect) std::vector<const ForceFields::UFF::AtomicParams *>;

/* pair */
// Use base types (int/unsigned int) to avoid duplicate swig::traits definitions
%template(Int_Pair) std::pair<int, int>;
%template(Double_Pair) std::pair<double,double>;
%template(UInt_Pair) std::pair<unsigned int, int>;
// Long_Pair removed - Ruby SWIG lacks swig::traits support for long long int

/* map */
%template(String_String_Map) std::map<std::string,std::string>;
%template(Int_Int_Map) std::map<int,int>;
// Point map templates removed - Ruby SWIG lacks swig::traits for custom types
// %template(Int_Point2D_Map) std::map<int, RDGeom::Point2D>;
// %template(Int_Point3D_Map) std::map<int, RDGeom::Point3D>;
%template(Int_Int_Vect_List_Map) std::map<int,std::list<std::vector<int> > >;

/* vector pair */
// Use base types (int/unsigned int) to avoid duplicate swig::traits definitions
%template(UInt_Pair_Vect) std::vector<std::pair<unsigned int,int> >;
%template(Match_Vect) std::vector<std::pair<int,int> >;
// Long_Pair_Vect removed - Ruby SWIG lacks swig::traits support for long long int

/* vector vector */
%template(Int_Vect_Vect) std::vector<std::vector<int> >;

/* list */
%template(Int_Vect_List) std::list<std::vector<int> >;
%template(Int_List) std::list<int>;
%template(UInt_List) std::list<unsigned int>;

/* other */
%template(Match_Vect_Vect) std::vector<std::vector<std::pair<int,int> > >;
// Flagged_Atomic_Params_Vect removed - Ruby SWIG lacks swig::traits for custom types
// %template(Flagged_Atomic_Params_Vect) std::pair<std::vector<const ForceFields::UFF::AtomicParams *>,bool>;
%template(Shared_Int_Array) boost::shared_array<int>;
%template(Shared_Double_Array) boost::shared_array<double>;

// These methods are renamed to valid method names
%rename(inc)   *::operator++;
%rename(good)  *::operator bool;
%rename(deref) *::operator->;
%rename(add)  *::operator+=;
%rename(idx)  *::operator[];

// Methods to get at elements of shared arrays
%extend boost::shared_array<double> {
  double getElement(int i) {
    return (*($self))[i];
  }
  void setElement(int i, double value) {
    (*($self))[i] = value;
  }
}
%extend boost::shared_array<int> {
  int getElement(int i) {
    return (*($self))[i];
  }
  void setElement(int i, int value) {
    (*($self))[i] = value;
  }
}

// This requires SWIG 4.2 or higher - must be before RDKitExceptions.i
%include "std_string_view.i"

// DO THIS BEFORE ANY OF THE OTHER INCLUDES
%include "../RDKitExceptions.i"

%include "../point.i"
// Need the types wrapper or we get undefined errors for STR_VECT
%include "../types.i"
// Conformer seems to need to come before ROMol
%include "../Conformer.i"
%include "../Dict.i"
%include "../RDLogger.i"
%include "../RDProps.i"
%include "../StereoGroup.i"
%include "../ROMol.i"
%include "../RWMol.i"
%include "../Bond.i"
%include "../BondIterators.i"
%include "../Atom.i"
%include "../AtomIterators.i"
%include "../AtomPairs.i"
%include "../Canon.i"
%include "../Conformer.i"
%include "../QueryAtom.i"
%include "../QueryBond.i"
%include "../QueryOps.i"
%include "../MolBundle.i"
%include "../MonomerInfo.i"
%include "../PeriodicTable.i"
%include "../SanitException.i"
%include "../SmilesParse.i"
%include "../SmilesWrite.i"
%include "../SmartsWrite.i"
%include "../MolOps.i"
%include "../MolSupplier.i"
%include "../MolWriters.i"
%include "../RingInfo.i"
%include "../ChemReactions.i"
%include "../BitOps.i"
%include "../ExplicitBitVect.i"
%include "../Fingerprints.i"
%include "../MorganFingerprints.i"
%include "../ReactionFingerprints.i"
%include "../Rings.i"
%include "../transforms.i"
%include "../DistGeom.i"
%include "../ForceField.i"
%include "../ChemTransforms.i"
%include "../Subgraphs.i"
%include "../MolTransforms.i"
%include "../FMCS.i"
%include "../MolDraw2D.i"
%include "../FilterCatalog.i"
%include "../Trajectory.i"
%include "../MolStandardize.i"
%include "../SubstructLibrary.i"
%include "../RGroupDecomposition.i"
%include "../ScaffoldNetwork.i"
%include "../TautomerQuery.i"
%include "../SubstanceGroup.i"
%include "../MolEnumerator.i"
%include "../MolHash.i"
%include "../Abbreviations.i"
%include "../Streams.i"
%include "../GeneralizedSubstruct.i"
%include "../RascalMCES.i"
%include "../Queries.i"
%include "../Subset.i"

%include "../Descriptors.i"

#ifdef RDK_BUILD_AVALON_SUPPORT
%include "../AvalonLib.i"
#endif
#ifdef RDK_BUILD_INCHI_SUPPORT
%include "../Inchi.i"
#endif
#ifdef RDK_BUILD_CHEMDRAW_SUPPORT
%include "../ChemDraw.i"
#endif

%include "../DiversityPick.i"

%{
#include <RDGeneral/versions.h>
%}

%immutable RDKit::rdkitVersion;
%immutable RDKit::boostVersion;
%immutable RDKit::rdkitBuild;

%include <RDGeneral/versions.h>
