/* 
* $Id$
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

%{
#include <boost/cstdint.hpp>
#include <DataStructs/BitVects.h>
#include <DataStructs/SparseIntVect.h>
#include <GraphMol/Fingerprints/AtomPairs.h>
%}
%include <DataStructs/BitVects.h>
%include <DataStructs/SparseIntVect.h>

// Use base types (int/unsigned int) instead of boost::int32_t/uint32_t to avoid
// duplicate swig::traits definitions (boost types are typedefs to base types)
%rename(eq) RDKit::SparseIntVect<unsigned int>::operator==;
%rename(ne) RDKit::SparseIntVect<unsigned int>::operator!=;
%rename(eq) RDKit::SparseIntVect<int>::operator==;
%rename(ne) RDKit::SparseIntVect<int>::operator!=;
// SparseIntVect<long long> operators removed - Ruby SWIG lacks swig::traits for long long int

%template(SparseIntVectu32) RDKit::SparseIntVect<unsigned int>;
%template(SparseIntVect32) RDKit::SparseIntVect<int>;
// SparseIntVect64 removed - Ruby SWIG lacks swig::traits for long long int

%ignore RDKit::SparseIntVect<unsigned int>::getNonzeroElements const;
%ignore RDKit::SparseIntVect<int>::getNonzeroElements const;

%extend RDKit::SparseIntVect<unsigned int> {
  std::vector<std::pair<unsigned int, int> > getNonzero() const{
    std::vector<std::pair<unsigned int, int> > res;
    for(std::map<unsigned int,int>::const_iterator es=$self->getNonzeroElements().begin();
        es!=$self->getNonzeroElements().end();++es){
      res.push_back(std::make_pair((unsigned int)es->first,(int)es->second));
    }
    return res;
  }
}
%extend RDKit::SparseIntVect<int> {
  std::vector<std::pair<int, int> > getNonzero() const{
    std::vector<std::pair<int, int> > res;
    for(std::map<int,int>::const_iterator es=$self->getNonzeroElements().begin();
        es!=$self->getNonzeroElements().end();++es){
      res.push_back(std::make_pair((int)es->first,(int)es->second));
    }
    return res;
  }
}
// getNonzero for SparseIntVect<boost::int64_t> removed - Ruby SWIG lacks swig::traits for long long int
// %extend RDKit::SparseIntVect<boost::int64_t> {
//   std::vector<std::pair<boost::int64_t, int> > getNonzero() const{
//     std::vector<std::pair<boost::int64_t, int> > res;
//     for(std::map<boost::int64_t,int>::const_iterator es=$self->getNonzeroElements().begin();
//         es!=$self->getNonzeroElements().end();++es){
//       res.push_back(std::make_pair((boost::int64_t)es->first,(int)es->second));
//     }
//     return res;
//   }
// }
%newobject getAtomPairFingerprint;
%newobject getHashedAtomPairFingerprint;
%newobject getHashedAtomPairFingerprintAsBitVect;
%newobject getTopologicalTorsionFingerprint;
%newobject getHashedTopologicalTorsionFingerprint;
%newobject getHashedTopologicalTorsionFingerprintAsBitVect;
%include <GraphMol/Fingerprints/AtomPairs.h>
