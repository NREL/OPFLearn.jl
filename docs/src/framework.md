# OPFLearn Framework

## Dataset Creation Method Overview

OPFLearn uses an efficient methodology to representatively sample from significant portions of the AC OPF feasible load space.
This methodology finds load samples by uniformly sampling from a convex set, the input space, which contains an AC OPF feasible set. 
Samples are then tested for AC OPF feasibility and are added to the dataset if they are feasible. 
The convex set is reduced throughout sampling by constructing separating hyperplanes to increase the likelihood of sampling feasible load profiles.

A flowchart of the OPFLearn framework can be seen below,

```@raw html
<div style="background-color:white; display:block; margin-left:auto; margin-right:auto; width:80%" >
<img src='../assets/flowchart.svg' style="display:block; margin-left:auto; margin-right:auto" width="100%" alt='OPFLearn flowchart'>
</div>
```


The loop exits when one of the given stopping conditions is met. 
Generally, this stopping criteria is the number of desired samples in the dataset.

Example iterations of this process are illustrated below where SOC represents the relaxed AC OPF feasible load space and AC represents the true AC OPF feasible load space. 

```@raw html
<div style="background-color:white; display:block; margin-left:auto; margin-right:auto; width:50%" >
<img src="../assets/procedure.svg" style="display:block; margin-left:auto; margin-right:auto" width="100%" alt="Iteration example">
</div>
```

**Steps from top left to bottom right:** 

(1) Find the Chebyshev center to use as the initial point, $x_0$. Generate a random direction vector and travel a random distance along this vector to find a new load sample, $x_l$. 

(2) Check if $x_l$ is AC OPF feasible. If it is not feasible, find the nearest relaxed feasible point, $x_l^*$. Because $\hat{x}_l \ne {x}_l^*$ define a new infeasibility certificate at $x_l^*$ with normal, $\vec{n} = \hat{x}_l - {x}_l^*$. 

(3) Gather a new sample, $x_l$, as in Step 1. Check if the new sampled load is AC OPF feasible. Here, it is not, so the nearest relaxed feasible point is found. $\hat{x}_l = x^*_l$ so discard this sample. 

(4) Sample a new load profile, $x_l$, as in Step 1, but starting from the last point, now $x_0$. Check if $x_l$ is AC OPF feasible. $x_l$ is AC OPF feasible, so store $x_l$ and its AC OPF optimal solution.

## Framework 

OPFLearn was developed to allow the user to specify functions for modular parts of the dataset creation process.
The following operations in the OPFLearn framework can be provided by the user. 
- **Initial Sampling Space**: The A and b matrices defining a polytope, Ax ≤ b.
- **Sampling Method**: A function to sample network load profiles given the current sampling space and nominal load.
- **AC OPF Relaxations**: The AC OPF problem relaxations used to find the maximum load demands and nearest feasible loads.
- **Optimization Solvers**: Solvers used to solve the relaxed and nonconvex AC OPF problems.

### Initial Sampling Space

The initial sampling space can be specified by provided A and b matrices that define a polytope, Ax ≤ b. 
By default this sampling space is initialized with the following constraints, 
- The active demand is less than the found maximum individual load bus demand values,
- The active demand is greater than zero,
- The reactive demand is greater than zero,
- The reactive demand is limited by the specified minimum power factor (default: 0.7071),
- The total active load is less than the sum of generator active power ratings.

The default initial sampling space is impacted by the following arguments,
- 'pd_max': The maximum active load for each load in the system. By default this is found with an optimization problem.
- 'pd_min': The minimum active load for each load in the system. By default this is 0.
- 'pf_min': A single number or array with values for each load in the system indicating the minimum power factor.
- 'pf_lagging': A boolean indicating if the power factor of loads are only lagging (inductive), or can be lagging or leading (inductive or capacitive).

### Sampling Method

A function for sampling load profiles from the sample space can be provided to the dataset creation functions through the `sampler` argument.
This function must accept four required arguments A, b, x0, n\_samples, where A & b define the sampling space as a polytope (Ax<b), x0 is a point within the sampling space, and n\_samples is the number of samples to produce.
Additionally the function can accept any number of optional arguments, which can be provided through the `sampler_opts` arguments as a dictionary mapping optional argument names as symbols to the desired parameter (e.g. :method => "hitandrun").

By default OPFLearn uses a [hit and run sample method translated from MATLAB (Copyright (c) 2011, Tim Benham).](https://www.mathworks.com/matlabcentral/fileexchange/34208-uniform-distribution-over-a-convex-polytope?s_tid=prof_contriblnk)

!!! note
	Note only the hit and run methods (hitandrun & achr) in the OPFLearn [`sample_polytope_cprnd`](@ref) function have been extensively tested.

!!! warn
	When creating datasets for networks with greater than around 50 loads, the default sampling method can become slow do to the high dimensionality of the sampling space and the often large number of infeasibility certificates found. Changing the sampler or sampling parameters can help speed up sampling. 

### AC OPF Relaxations

The relaxations to formulate relaxed AC OPF problems can be specified with the `model_type` argument for dataset creation functions. 
Most relaxations available in the PowerModels.jl package can be used. A list of these [PowerModels relaxations can be found here](https://lanl-ansi.github.io/PowerModels.jl/stable/formulation-details/#Quadratic-Relaxations).
By default OPFLearn uses [a Strengthened QC-Relaxation](https://lanl-ansi.github.io/PowerModels.jl/stable/formulation-details/#PowerModels.QCLSPowerModel), 'PowerModels.QCLSPowerModel'.

!!! note
	Note that for conic relaxations, such as PowerModels.SDPWRMPowerModel, a non-default solver will likely need for be used.

### Optimization Solvers

The solvers used for solving the relaxed and nonconvex AC OPF problems can be specified with `r_solver` and `opf_solver`, respectively.
By default [IPOPT](https://github.com/jump-dev/Ipopt.jl) is used to solve all AC OPF problems.

## Additional Dataset Creation Arguments

A complete list of arguments for the `create_samples` can be found in the functions documentation,

```@docs
create_samples
```

### Stopping Criteria

The criteria used to stop sampling can be set to include any of the following, 
- K: The maximum number of samples
- U: 1/U indicates the maximum number of samples since the last unique active set found
- S: 1/S indicates the maximum number of samples since the last sample was saved to the dataset
- V: 1/V indicates the maximum number of samples since the last feasible sample increased the variance of its unique active set
- T: The maximum amount of time for the creation of the dataset
- max_iter: The maximum amount of total iterations when creating the dataset

When multiple criteria are used, sampling will stop when any one of the used criteria are satisfied.
To exclude the maximum number of samples criteria set K to Inf (np.Inf in Python).