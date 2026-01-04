/* -----------------------------------------------------------------------------
 * extend_std_vector.i
 * ----------------------------------------------------------------------------- */

// Note: The generic %extend std::vector with template parameter T doesn't work
// properly with SWIG Ruby backend. The equals() and vector(size_type) methods
// that use T directly cause compilation errors in the generated wrapper code.
// These extensions are removed for Ruby compatibility.

%include <std_vector.i>
