# Dataset Format

The results are returned as a dictionary, which can be converted to an array with the `results_to_array` function.
This resulting array has the same format as the exported datasets from `results_to_csv`. 


The array formatted datasets have column headers indicating variables and each row contains the data for one sample.
Columns are organized with variables in the order of input variables, output variables, then dual variables. The order 
of variables within each section is determined by the order of the variables given through the result variable array arguments.
For each variable there is a column corresponding to each element in the network. 
The header for a column indicating the active power demand at the first load bus would be "load1:pl".
An example results 'csv' file header can be seen below for the pjm case5 network,

| load1:pl | load2:pl | load3:pl | load1:ql | load2:ql | load3:ql | gen1:pg | gen2:pg  | ... |
|----------|----------|----------|----------|----------|----------|---------|----------|-----|
| 4.593425 | 6.023329 | 3.397289 | 2.522202 | 1.098917 | 0.522865 | 0.4     | 1.7      | ... |
| 4.516742 | 4.325241 | 5.034486 | 1.025272 | 1.499984 | 3.382087 | 0.4     | 1.7      | ... |
| 3.936777 | 5.626792 | 1.330743 | 2.183705 | 0.385759 | 1.027381 | 0.4     | 1.363544 | ... |
| ...      | ...      | ...      | ...      | ...      | ...      | ...     | ...      | ... |
