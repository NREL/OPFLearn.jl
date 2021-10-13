# Create worker processes
nproc = 4 # The desired number of CPUs to run with #Sys.CPU_THREADS
# Clear any existing worker processes if present
Distributed.nprocs() > 1 && Distributed.rmprocs(Distributed.workers())
# Create worker processes
Distributed.addprocs(nproc - 1; exeflags="--project")
# Import functions used on all worker processes
Distributed.@everywhere using OPFLearn
#Distributed.@everywhere import OPFLearn: sample_producer, sample_processor

results = OPFLearn.dist_create_samples("test//data//pglib_opf_case14_ieee.m", 10, nproc=4)