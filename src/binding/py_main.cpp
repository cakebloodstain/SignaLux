#include <nanobind/nanobind.h>
#include <nanobind/stl/string.h>
#include <signalux/signalux.h>

namespace nb = nanobind;

NB_MODULE(_signalux, m) {
    m.doc() = "Python bindings for the SignaLux C++ library";

    m.def("get_greeting", &signalux::get_greeting, "Returns a greeting string");
}
