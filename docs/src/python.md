## Python Interface

A Python package to interface OPFLearn with Python can be found at [opflearn]().
This package utilizes [PyJulia](https://github.com/JuliaPy/pyjulia) to allow Python users to create datasets from a Python enviroment.

The Python interface has most functions from OPFLearn.jl as Python functions, but not all.
For functions that are not included in the interface, PyJulia calls can be used.
Also note that the Python interface does not allow for passing in custom functions for sampling.
