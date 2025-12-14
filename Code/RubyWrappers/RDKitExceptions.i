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

// Defines all of the C++ -> Java exception handling

%{
#include <RDGeneral/Exceptions.h>
#include <RubyWrappers/GenericRDKitException.h>
%}

// Note that these files must follow the typemap declarations
%include <RDGeneral/Exceptions.h>
%include <RubyWrappers/GenericRDKitException.h>

%exception {
  try {
     $action
  } catch (RDKit::ChemicalReactionException &e) {
    static VALUE exceptionError = rb_define_class("ChemicalReactionException", rb_eRuntimeError);
    rb_raise(exceptionError, "%s", e.what());
  } catch (RDKit::ChemicalReactionParserException &e) {
    static VALUE exceptionError = rb_define_class("ChemicalReactionParserException", rb_eRuntimeError);
    rb_raise(exceptionError, "%s", e.what());
  } catch (RDKit::ConformerException &e) {
    static VALUE exceptionError = rb_define_class("ConformerException", rb_eRuntimeError);
    rb_raise(exceptionError, "%s", e.what());
  } catch (RDKit::MolPicklerException &e) {
    static VALUE exceptionError = rb_define_class("MolPicklerException", rb_eRuntimeError);
    rb_raise(exceptionError, "%s", e.what());
  } catch (RDKit::MolSanitizeException &e) {
    static VALUE exceptionError = rb_define_class("MolSanitizeException", rb_eRuntimeError);
    rb_raise(exceptionError, "%s", e.what());
  } catch (RDKit::SmilesParseException &e) {
    static VALUE exceptionError = rb_define_class("SmilesParseException", rb_eRuntimeError);
    rb_raise(exceptionError, "%s", e.what());
  } catch (KeyErrorException &e) {
    static VALUE exceptionError = rb_define_class("KeyErrorException", rb_eRuntimeError);
    rb_raise(exceptionError, "%s", e.what());

  // Generic exception -- anything else
  } catch (std::exception &e) {
    static VALUE exceptionError = rb_define_class("GenericRDKitException", rb_eRuntimeError);
    rb_raise(exceptionError, "%s", e.what());
  }
}
