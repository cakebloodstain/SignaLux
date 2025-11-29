import os
import sys
import subprocess

# Add Python bindings to path
sys.path.insert(0, os.path.abspath("../../src/python_bindings/"))

extensions = [
    "breathe",          # Import Doxygen XML
    "sphinx.ext.autodoc",
    "sphinx.ext.napoleon",
    "sphinx.ext.autosummary",
]

breathe_projects = {
    "SignaLux": "../build/xml"   # Output from Doxygen
}

breathe_default_project = "SignaLux"

html_theme = "sphinx_rtd_theme"

autodoc_default_options = {
    "members": True,
    "undoc-members": True,
}

autosummary_generate = True
