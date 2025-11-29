find_package(Doxygen REQUIRED)

set(DOXYGEN_IN ${CMAKE_CURRENT_SOURCE_DIR}/Doxyfile.in)
set(DOXYGEN_OUT ${CMAKE_CURRENT_BINARY_DIR}/Doxyfile)

configure_file(${DOXYGEN_IN} ${DOXYGEN_OUT})

add_custom_target(doc_doxygen
    COMMAND ${DOXYGEN_EXECUTABLE} ${DOXYGEN_OUT}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Generating C++ API documentation with Doxygen"
)

# Sphinx
find_package(Sphinx REQUIRED)

add_custom_target(doc_sphinx
    COMMAND ${SPHINX_EXECUTABLE} -b html
            ${CMAKE_CURRENT_SOURCE_DIR}/source
            ${CMAKE_CURRENT_BINARY_DIR}/html
    DEPENDS doc_doxygen
    COMMENT "Building Sphinx HTML documentation"
)

add_custom_target(doc ALL
    DEPENDS doc_doxygen doc_sphinx
)
