# OPFLearn.jl

<img src="https://github.com/TragerJoswig-Jones/OPFLearn.jl/blob/main/docs/src/assets/logo.svg?raw=true" align="left" width="250" alt="OPFLearn logo">

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://tragerjoswig-jones.github.io/OPFLearn.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://tragerjoswig-jones.github.io/OPFLearn.jl/dev)
[![Build Status](https://github.com/tragerjoswig-jones/OPFLearn.jl/workflows/CI/badge.svg)](https://github.com/tragerjoswig-jones/OPFLearn.jl/actions)
[![Coverage](https://codecov.io/gh/tragerjoswig-jones/OPFLearn.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/tragerjoswig-jones/OPFLearn.jl)

OPFLearn.jl is a Julia package for creating datasets for machine learning approaches to solving AC optimal power flow (AC OPF).
It was developed to provide researchers with a standardized way to efficiently create AC OPF datasets that are representative of more of the AC OPF feasible load space compared to typical dataset creation methods.
The OPFLearn dataset creation method uses a relaxed AC OPF formulation to reduce the volume of the unclassified input space throughout the dataset creation process. 
Over time this input space tightens around the relaxed AC OPF feasible region to increase the percentage of feasible load profiles found while uniformly sampling the input space. Load samples are processed using AC OPF formulations from [PowerModels.jl](https://github.com/lanl-ansi/PowerModels.jl).
More information on the dataset creation method can be found in our publication, "OPF-Learn: An Open-Source Framework for Creating Representative AC Optimal Power Flow Datasets".

To use OPFLearn.jl a [PowerModels network data dictionary](https://lanl-ansi.github.io/PowerModels.jl/stable/network-data/) is required (can be loaded from Matpower ".m" files) to define the network the dataset is being created for.
Datasets created using OPFLearn.jl can be specified to save the following parameters in per unit,

| **Input Data**           | **Output Data**                          | **Dual Data**                               |
|--------------------------|------------------------------------------|---------------------------------------------|
| • Load Active Power (pl)<br>• Load Reactive Power (ql)   | • Generator Active Power (pg)<br>• Generator Reactive Power (qg)<br>• Generator Voltage Magnitude  (vm_gen)<br>• Bus Voltage  (v_bus) <br>• Edge To Active Power (p_to) <br>• Edge From Active Power (p_fr)  <br>• Edge To Reactive Power (q_to)  <br>• Edge From Reactive Power (q_fr)                | • Min Bus Voltage (v_min)<br>• Max Bus Voltage (v_max) <br>• Min Generator Active Power (pg_min)<br>• Max Generator Active Power (pg_max)<br>• Min Generator Reactive Power (qg_min)<br>• Max Generator Reactive Power (qg_max)<br>• Max Edge To Active Power (p_to_max)<br>• Max Edge From Active Power (p_fr_max<br>• Max Edge To Reactive Power (q_to_max) <br>• Max Edge From Reactive Power (q_fr_max)                |


## Documentation

The package [documentation](https://TragerJoswig-Jones.github.io/OPFlearn.jl/stable/) includes a variety of useful information including a [quick-start guide](https://TragerJoswig-Jones.github.io/OPFLearn.jl/stable/quickguide/).


## Available Datasets
Datasets with 10,000 samples for [PGLib-OPF test networks](https://github.com/power-grid-lib/pglib-opf) case5_pjm, case14_ieee, case30_ieee, case57_ieee, and case118_ieee, can be found on the [NREL Data Catalog here]().

## Acknowledgments

The development of this code was supported in part by the U.S. Department of Energy, Office
of Science, Office of Workforce Development for Teachers and Scientists
(WDTS) under the Science Undergraduate Laboratory Internships Program
(SULI), and the Laboratory Directed Research and Development (LDRD) Program at NREL.

The primary developer is Trager Joswig-Jones (@tragerjoswig-jones) with support from the following contributors,
- Ahmed S. Zamzam (@asazamzam) NREL, Project Technical Lead and developed original OPFLearn MATLAB code
- Kyri Baker (@kyrib) CU Boulder, Advised on original AC OPF formulations and dataset creation method


## Citing OPFLearn

If you find OPFlearn useful in your work, we kindly request that you cite the following [publication]():
```
@inproceedings{__,
  author = {Trager Joswig-Jones and Ahmed S. Zamzam and Kyri Baker},
  title = {OPF-Learn: An Open-Source Framework for Creating Representative AC Optimal Power Flow Datasets},
  booktitle = {},
  year = {2021},
  month = {},
  pages = {1-5},
  doi = {}
}
```
Citation of [PowerModels](https://github.com/lanl-ansi/PowerModels.jl), used for formulating AC OPF problems is also encouraged when publishing works that use OPFLearn. Note that OPFLearn was NOT developed in any part in collaboration with PowerModels.jl.


## License

This code is provided under a modified BSD-3 license
