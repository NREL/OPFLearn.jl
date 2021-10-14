
# OPFLearn.jl Documentation

```@meta
CurrentModule = OPFLearn
```

## Package Overview

[OPFLearn.jl](https://github.com/tragerjoswig-jones/OPFLearn.jl) is a Julia package for creating datasets for machine learning approaches to solving AC optimal power flow (AC OPF).
It was developed to provide researchers with a standardized way to efficiently create AC OPF datasets that are representative of more of the AC OPF feasible load space compared to typical dataset creation methods.
The OPFLearn dataset creation method uses a relaxed AC OPF formulation to reduce the volume of the unclassified input space throughout the dataset creation process. 
Over time this input space tightens around the relaxed AC OPF feasible region to increase the percentage of feasible load profiles found while uniformly sampling the input space. Load samples are processed using AC OPF formulations from [PowerModels.jl](https://github.com/lanl-ansi/PowerModels.jl).
More information on the dataset creation method can be found in our publication, "OPF-Learn: An Open-Source Framework for Creating Representative AC Optimal Power Flow Datasets". A Python interface for OPFLearn.jl is available at [opflearn](https://github.com/TragerJoswig-Jones/opflearn).

## Installation

If you haven’t already, your first step should be to install Julia. Instructions are available at julialang.org/downloads.

Installing OPFLearn now takes two steps using the Julia package manager.

First, add NREL’s Julia package registry to your Julia installation. 
From the main Julia prompt, type ] to enter the package management REPL. 
Type (or paste) the following,

```julia
] registry add https://github.com/NREL/JuliaRegistry.git
```

Then install the OPFLearn package with,

```julia
] add OPFLearn
```

To use different formulations for the creating the relaxed AC OPF problems, such as a Semidefinite Relaxation, additional solvers are required. 
For conic AC OPF formulations a conic solver must be installed. OPFLearn was tested with the SCS solver, which can be installed with

```julia
] add SCS
```

Testing that the OPFLearn package works properly can be done with 

```julia
] test OPFLearn
```

!!! note
	OPFLearn can take a while to start up as Julia takes a notable amount of time to precompile IPOPT. 

!!! warn
	In the current release of OPFLearn the distributed dataset creation tests can get stuck loading packages on distributed processes. 
	If you run into this issue, you can inturrupt these tests with 'ctrl+c'. 