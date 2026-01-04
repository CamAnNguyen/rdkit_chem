/*
*
*  This file is part of the RDKit.
*  The contents are covered by the terms of the BSD license
*  which is included in the file license.txt, found at the root
*  of the RDKit source tree.
*
*/
%include "std_vector.i"


%{
#include <vector>
#include <GraphMol/TautomerQuery/TautomerQuery.h>
%}
%shared_ptr(RDKit::ROMol)
%template(Sizet_Vect) std::vector<size_t>;

%include <GraphMol/TautomerQuery/TautomerQuery.h>
