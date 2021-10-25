
# OPFLearn.jl Documentation

```@meta
CurrentModule = OPFLearn
```

## Package Overview

[OPFLearn.jl](https://github.com/NREL/OPFLearn.jl) is a Julia package for creating datasets for machine learning approaches to solving AC optimal power flow (AC OPF).
It was developed to provide researchers with a standardized way to efficiently create AC OPF datasets that are representative of more of the AC OPF feasible load space compared to typical dataset creation methods.
The OPFLearn dataset creation method uses a relaxed AC OPF formulation to reduce the volume of the unclassified input space throughout the dataset creation process. 
Over time this input space tightens around the relaxed AC OPF feasible region to increase the percentage of feasible load profiles found while uniformly sampling the input space. Load samples are processed using AC OPF formulations from [PowerModels.jl](https://github.com/lanl-ansi/PowerModels.jl).
More information on the dataset creation method can be found in our publication, "OPF-Learn: An Open-Source Framework for Creating Representative AC Optimal Power Flow Datasets". A Python interface for OPFLearn.jl is available at [opflearn](https://github.com/TragerJoswig-Jones/opflearn).

## Installation

If you haven’t already, your first step should be to install Julia. Instructions are available at [julialang.org/downloads](https://julialang.org/downloads/).

Installing OPFLearn can now be done using the Julia package manager.

```julia
] add OPFLearn
```

For the development version of OPFLearn, install the package with,

```julia
] add OPFLearn#main
```

By default OPFLearn uses [IPOPT](https://github.com/jump-dev/Ipopt.jl) to solve AC OPF problems, which comes installed as a dependancy of OPFLearn.
When using different formulations for relaxed AC OPF problems, such as a Semidefinite Relaxation, additional solvers are required. 
For conic AC OPF formulations a conic solver must be installed. OPFLearn was tested with the [SCS](https://github.com/jump-dev/SCS.jl) solver, which can be installed with

```julia
] add SCS
```

Testing that the OPFLearn package works properly can be done with 

```julia
] test OPFLearn
```

!!! note
	OPFLearn can take a while to start up on the first run of each session as Julia takes a notable amount of time to precompile IPOPT. 

!!! warn
	In the current release of OPFLearn the distributed dataset creation tests can get stuck loading packages on distributed processes. 
	If you run into this issue, you can inturrupt these tests with 'ctrl+c'. 
