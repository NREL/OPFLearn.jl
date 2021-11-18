module OPFLearn

import Dates
using DelimitedFiles: readdlm, writedlm
import Distributed
import LinearAlgebra: diag, eigvals, I, cholesky, norm, Hermitian, dot, norm, logdet

import OnlineStatsBase: fit!, CovMatrix, Variance
import OnlineStats: Series
import StatsBase: sample

import JuMP
import MathOptInterface
const MOI = MathOptInterface
import PowerModels
import PowerModels: ref, ids, var
const PM = PowerModels

import Random

import Ipopt

include("create_samples.jl")
include("create_samples_distributed.jl")
include("tasks.jl")

include("formulations.jl")
include("run_ac_opf.jl")

include("network.jl")
include("results.jl")
include("io.jl")
include("sample.jl")
include("export.jl")

const TOL = 1e-6
const INFEASIBILITY_CERT_SHIFT = 0.0  # Tune this parameter based on willingness to cut out large loads
const FNFP_SHIFT = 1e-2  # Increase to find more AC-OPF feasible points as FNFP problem
const R_TOLERANCE = 1e-5  # 10x tolerance used for solving Nearest Feasible load problem

const NW_DEFAULT = PM.nw_id_default # The first network index for a PowerModels network. 
				      # OPFLearn currently only supports single network models.

const SOLVED_STATUSES = [MOI.OPTIMAL, MOI.LOCALLY_SOLVED, MOI.ALMOST_OPTIMAL, MOI.ALMOST_LOCALLY_SOLVED]

const EPS = 1e-5
const STAT_ORDER = ["pd", "qd", "pg", "vm_gen"]
const DEFAULT_INPUTS = ["pd", "qd"]
const DEFAULT_OUTPUTS = ["p_gen", "q_gen", "vm_gen", "vm_bus", "va_bus", 
						 "p_to", "q_to", "p_fr", "q_fr"]
# "vm" and "va" can be added for voltage magnitudes and angles at each bus
const DEFAULT_DUALS = ["v_min", "v_max", "pg_min", "pg_max", "qg_min", "qg_max",
					   "pto_max", "qto_max", "pfr_max", "qfr_max"]

const DEFAULT_SAVE_ORDER = vcat(DEFAULT_INPUTS, DEFAULT_OUTPUTS, DEFAULT_DUALS)

const ELEMENT_LABELS = Dict(zip(append!(DEFAULT_SAVE_ORDER, ["v_bus", "total_cost"]), 
				    ["load", "load",
					 "gen", "gen", "gen", "bus", "bus",
					 "line", "line", "line", "line",
					 "bus", "bus", "gen", "gen", "gen", "gen",
					 "line", "line", "line", "line",
					 "bus", "net"]))

const VAR_SIZES = Dict([
					 ("v_min", [:n_buses]),
					 ("v_max", [:n_buses]),
					 ("pg_min", [:n_gens, :n_ext]),
					 ("pg_max", [:n_gens, :n_ext]),
					 ("qg_min", [:n_gens, :n_ext]),
					 ("qg_max", [:n_gens, :n_ext]),
					 ("pfr_max", [:n_branches]),
					 ("pto_max", [:n_branches]),
					 ("qfr_max", [:n_branches]),
					 ("qto_max", [:n_branches]),
					 ("pd", [:n_loads]),
					 ("qd", [:n_loads]),
					 ("p_gen", [:n_gens, :n_ext]),
					 ("q_gen", [:n_gens, :n_ext]),
					 ("v_bus", [:n_buses]),
					 ("vm_gen", [:n_gens, :n_ext]),
					 ("vm_bus", [:n_buses]),
					 ("va_bus", [:n_buses]),
					 ("p_fr", [:n_branches]),
					 ("p_to", [:n_branches]),
					 ("q_fr", [:n_branches]),
					 ("q_to", [:n_branches]),
					 ("q_to", [:n_branches]),
					 ("total_cost", [:n_nets]),
					 ])

end
