# [Distributed Processing](@id distributed_processing)

Dataset creation can be sped up by using distributed processing. 
Before beginning distributed dataset creation, the user must create worker processes through the [Distributed](https://docs.julialang.org/en/v1/stdlib/Distributed/) package. 
A simple way to do this when running distributed processes locally on a single computer is as follows, 

```julia
# Create worker processes
nproc = 4 # The desired number of CPUs to run with
# Clear any existing worker processes if present
Distributed.nprocs() > 1 && Distributed.rmprocs(Distributed.workers())
# Create worker processes
Distributed.addprocs(nproc - 1; exeflags="--project")
# Import functions used on all worker processes
Distributed.@everywhere using OPFLearn
```

The `create_samples` function has a distributed alternative, `dist_create_samples`.

```@docs
dist_create_samples
```

The distributed sample creation function has the same arguments as the single process function, except for the addition of two arguments: `nproc` and `replace_samples`.
- `nproc` allows the user to specify the number of processor to run the distributed sample creation with.
- `replace_samples` specifies whether when a new infeasibility certificate is found if the samples in the sample queue are replaced.

!!! warn
	The replace samples option has not been fully tested/debugged and may cause the script to freeze.

Distributed processing splits the sampling/result handling from the sample processing with one processor handling sampling and the remaining processors processing samples.

!!! note
	A significant increase in speed is not seen unless more than 3 processors are used. On the other hand, specifying more processors than are available may result in an error when loading OPFLearn on distributed processes.