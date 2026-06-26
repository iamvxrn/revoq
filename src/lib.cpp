// nlohmann/json is header-only: every symbol is a template or inline
// function defined in include/. This translation unit exists only because
// deft's strict layout requires a src/lib.cpp entry point to identify the
// package as a buildable C++ library — compiling it validates the headers
// but produces no symbols of its own beyond what each consumer instantiates.
#include <nlohmann/json.hpp>
