## Python Interface

A Python package to interface OPFLearn with Python can be found at [opflearn](https://github.com/TragerJoswig-Jones/opflearn).
This package utilizes [PyJulia](https://github.com/JuliaPy/pyjulia) to allow Python users to create datasets from a Python enviroment. 
A guide on how to install PyJulia and run Julia scripts from Python can be found [here](https://pyjulia.readthedocs.io/en/latest/installation.html). 
Once Julia is installed, the OPFLearn package must be installed as shown in the [Installation](@ref) section.

The opflearn Python package is NOT on the Python Package Index Repository, so it has to be install from GitHub as follows,

```cmd
pip install git+https://github.com/TragerJoswig-Jones/opflearn.git
```

The Python interface has most of the same Julia functions from OPFLearn.jl as callable Python functions, but not all.
For functions that are not included in the interface, PyJulia calls can be used.

!!! note
	This Python interface sometimes requires using values from [NumPy](https://numpy.org/) and does not allow for passing in modular functions.
