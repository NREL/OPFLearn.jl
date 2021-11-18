# Quick Start Guide

With OPFLearn installed and a network data file (e.g. `"pglib_opf_case5_pjm.m"`) available in the current directory, an AC OPF dataset with N samples can be created with,

```julia
using OPFLearn
N = 100

results = create_samples("pglib_opf_case5_pjm.m", N)
```

!!! note
	When creating datasets for networks with greater than around 50 buses, runtimes can be improved by reducing the initial sampling space through either the 'pd_max', 'pd_min', or 'pf_min' arguments. OPFLearn has been tested on networks up to 300 buses with 'pd_max' specified as 2 times the nominal load at each bus. For 'pglib_opf_case300_ieee' a dataset of 15,000 samples took approximately a day to create using 40 distributed processors on an HPC node.

## Getting Results

OPFLearn's create_samples functions return the resulting sample data as a dictionary. 
This dictionary contains sub-dictionaries containing feasible AC OPF sample input, output, and lagrangian dual values. 
Each of these three primary data category's dictionaries map variable key values to arrays containing the corresponding data for relevent elements in the network. 
These arrays are two dimensional with columns corresponding to elements in the system and rows corresponding to different AC OPF samples. 

The input data, queried with `results["inputs"]`, is a dictionary containing information for input variables to the AC OPF problem.
The output data, queried with `results["outputs"]`, is a dictionary of AC OPF solutions corresponding to the input data load profiles.
The dual data, queried with `results["duals"]`, is a dictionary containing information about the lagrangian dual values found when solving the AC OPF problem for each sample. Nonzero values (In OPFLearn values greater than 1e-5) indicate that the contraint associated with a dual value is active.

For example, the following dictionary query can be used to find the active power, `pd`, at each load in the network for the first saved AC OPF sample,

```julia
results["inputs"]["pd"][1,:]
```

Note that input and output data is in per unit. The base MVA can be found from the [PowerModels network data dictionary](https://lanl-ansi.github.io/PowerModels.jl/stable/network-data/).

By default input, output, and dual result data for all variables are saved to the results object. 
To reduce the size of the resulting data an array of the desired variables can be provided in the create samples call. 
For example, if you are only interested in saving the generator active power, `pg`, and generator bus voltage magnitudes, `vm_gen`, the following call can be made,

```julia
outputs = ["pg", "vm_gen"]
results = create_samples("pglib_opf_case5_pjm.m", N, output_vars=outputs)
```

This results object will only contain output data for these two specified output varaibles. Note, the input and dual results will still contain all the default variables, unless also specified.


## Additional Results

More information from each run can be saved by specifying additional parameters when calling create samples. 
This information includes iteration statistics, found maximum load bus demands, infeasible AC OPF samples, and the sampling space polytope definition.
See the [Additional Results](@ref additional_results) section for instructions on how to enable saving these additional results.

## Distributed Processing

If there are multiple processors available, the runtime to create samples can be reduced by using distributed processing. 
OPFLearn has addition functions for creating AC OPF datasets that utilize distributed processing, which can be read about in the [Distributed Processing](@ref distributed_processing) section.
