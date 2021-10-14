# OPFLearn Result Data

## Result Dataset Dictionary 

Resulting datasets are returned as a dictionary of values. This dictionary uses strings as key values.
A default result dictionary contains inputs, outputs, and duals data, structured as follows.

```json
{
"inputs":<Dictionary>,  # input variables to the AC OPF problem
"outputs":<Dictionary>, # AC OPF solutions corresponding to the input load profiles
"duals":<Dictionary>,   # lagrangian dual values found when solving the AC OPF problem
...
}
```

Each of these default result keys maps to a dictionary containing variables from the AC OPF problem that map to an array of result values for each sample in the dataset.
For example, the inputs, `results["inputs"]`, would return the following dictionary with active and reactive load variables mapping to a 2-dimensional array of values.

```
{
"pl": [...],
"ql": [...],
}
```

Then looking at the data for the active load with key "pl", `results["inputs"]["pl"]`, would return an array structured as follows,

```
sample 1: [pl_1, pl_2, ..., pl_n]
sample 2: [pl_1, pl_2, ..., pl_n]
sample 3: [pl_1, pl_2, ..., pl_n]
...
sample K: [pl_1, pl_2, ..., pl_n]
```

where pl_n indicates the value of the active power demand at bus n. 

### Specifying Results

By default input, output, and dual result data for all variables are saved to the results object. 
To reduce the size of the result object a subsection of the variables to save can be provided in the create samples call. 
For example, if you are only interested in saving the generator active power, `pg`, and generator bus voltage magnitudes, `vm_gen`, the following call can be made,

```
outputs = ["pg", "vm_gen"]
results = create_samples("pglib_opf_case5_pjm.m", N, output_vars=outputs)
```

This results object will only contain subdictionaries for these two specified output varaibles. The input and dual results will still contain all the default variables, unless also specified.

All the available result variables can be seen in this table,

```@raw html
<table>
  <tbody>
    <tr>
		<th><b>Input Data</b></th>
		<th><b>Output Data</b></th>
		<th><b>Dual Data</b></th>
	</tr>
	
    <tr>
		<td>
			<ul><li>Load Active Power (pl)</li><li>Load Reactive Power (ql)
			</li></ul>
		</td>
		<td>	
			<ul><li>Generator Active Power (pg)</li><li>Generator Reactive Power (qg)</li><li>Generator Bus Voltage Magnitude (vm_gen)</li><li>Bus Voltage (v_bus)</li><li>Edge To Active Power (p_to)</li><li>Edge From Active Power (p_fr)</li><li>Edge To Reactive Power (q_to)</li><li>Edge From Reactive Power (q_fr)</li></ul>
		</td>
		<td>
			<ul><li>Min Bus Voltage (v_min)</li><li>Max Bus Voltage (v_max)</li><li>Min Generator Active Power (pg_min)</li><li>Max Generator Active Power (pg_max)</li><li>Min Generator Reactive Power (qg_min)</li><li>Max Generator Reactive Power (qg_max)</li><li>Min Edge To Active Power (p_to_min)</li><li>Max Edge To Active Power (p_to_max)</li><li>Min Edge From Active Power (p_fr_min)</li><li>Max Edge From Active Power (p_fr_max)</li><li>Min Edge From Reactive Power (q_fr_min)</li><li>Max Edge From Reactive Power (q_fr_max)</li></ul>
		</td>
	</tr>
  </tbody>
</table>
```

### Converting to an Array

The result data dictionary can be converted to an array for easier data analysis with the [`results_to_array`](@ref) function.

## Additional Results (@id additional_results)

Additional result parameters can be saved if specified in the function call to create the dataset.
The additional results parameters are, 
- Iteration Statistics:
- Sampling Polytope:  
- Found Maximum Loads: 
- Infeasible Inputs: 

Arguments can be passed in to the dataset creation function, to have these additional results in the results dictionary.

### Iteration Statistics

To save iteration statistics the `stat_track` argument can be specified as an Integer from 1 to 3.

```julia
results = create_samples(net_file, K, stat_track=1)
```

Specifying a larger integer will save more information as follows,

| **Stat Track Level** | **Additional Data Saved** |
|----------------------|---------------------------|
| 0                    | None                      |
| 1                    | New Unique Active Set, New Infeasibility Certificate, Feasible Sample, Added Sample, Iteration Time, Increased Set Variance |
| 2                    | Unique Active Sets in The Dataset |
| 3                    | Unique Active Set Covariance Matrices |

This information can then be found in the results dictionary with `results["stats"]`. 

!!! warn
	For large datasets or networks using a level greater than 1 will likely result in a large amount of memory usage.

!!! note
	Variance tracking needs to be turned on with the boolean `variance` argument for data to be saved with `stat_track=3`.

### Sampling Polytope

To save the polytope that was used for sampling the `save_certs` argument should be specified as `true`.

```julia
results = create_samples(net_file, K, save_certs=true)
```

This will save the final definition of the polytope used for sampling input load demands, including the infeasibility certificates added to the initial sampling space.
The polytope is defined by Ax <= b, where A and b are matrices and x is a vector of the demands at each load bus in the network. 
Each row of the A and b matrices specifies a hyperplane contraint that defines the input load space that samples are pulled from.
These matrices are stored as arrays at `results["polytope"]["A"]` and `results["polytope"]["b"]`. These matrices can be passed into
a new call to a dataset creation function, with the arguments `A` and `b`, to initialize the sampling polytope with this polytope containing the infeasibility certificates found during the last run. 

### Found Maximum Loads

To save the maximum loads used to initialize the input load space the `save_max_load` argument should be specified as `true`.

```julia
results = create_samples(net_file, K, save_max_load=true)
```

This will store an array of maximum loads found at each bus in the network at `results["load_constraints"]["pl_max"]`. 
This array can be provided as an argument, `pl_max`, to a dataset creation function, when using the same network, to reduce the dataset creation initialization time.

### Infeasible Inputs

To save the infeasible AC OPF load samples found throughout dataset creation the `save_infeasible` argument should be specified as `true`.

```julia
results = create_samples(net_file, K, save_infeasible=true)
```

These results, at `results["infeasible_inputs"]`, contain all AC OPF infeasible load profiles input values found during the creation of a dataset.

## Exporting Results

Multiple functions are available to save OPFLearn datasets and other result data to 'csv' files.

### Dataset 

To export an AC OPF dataset the `save_results_csv` function can be used as follows, 

```julia
results = create_samples(net_file, K)
file_name = "dataset"
save_results_csv(results, file_name)
```

where `results` contains the dataset to be saved, and file_name is the name that the file will be saved as.
The format of the exported results 'csv' file is explained in the [Dataset Format](@ref) Section

### Statistics

Similarly, to export the iteration statistics the function `save_stats` can be used as follows,

```julia
stats = results["stats"]
save_stats(stats, file_name)
```

Note that this only saves the statistics stored with `stat_track=1`.

### Polytope

To export the Polytope A and b matrices the function `save_polytope` can be used as follows,

```julia
A = results["polytope"]["A"]
b = results["polytope"]["b"]
save_polytope(A, b, file_name)
```

Note that this saves the A and b matrices in two seperate 'csv' files.

### Save While Processing

The `save_while` argument can be specified as `true` to save all result values to files during the creation of the AC OPF dataset.
This ensures that dataset results are not lost if an error is encountered during the creation of large datasets. 
All values are saved to 'csv' files. 
