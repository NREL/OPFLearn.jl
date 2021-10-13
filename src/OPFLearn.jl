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

import GLPK
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
const STAT_ORDER = ["pl", "ql", "pg", "vm_gen"]
const DEFAULT_INPUTS = ["pl", "ql"] 
const DEFAULT_OUTPUTS = ["pg", "qg", "vm_gen", "v_bus", 
						 "p_to", "q_to", "p_fr", "q_fr"]
const DEFAULT_DUALS = ["v_min", "v_max", "pg_min", "pg_max", "qg_min", "qg_max",
					   "p_to_max", "q_to_max", "p_fr_max", "q_fr_max"]

const DEFAULT_SAVE_ORDER = vcat(DEFAULT_INPUTS, DEFAULT_OUTPUTS, DEFAULT_DUALS)

const ELEMENT_LABELS = Dict(zip(DEFAULT_SAVE_ORDER, 
				    ["load", "load", 
					 "gen", "gen", "gen", "bus", 
					 "line", "line", "line", "line",
					 "bus", "bus", "gen", "gen", "gen", "gen",
					 "line", "line", "line", "line"]))

const VAR_SIZES = Dict([
					 ("v_min", [:n_buses]),
					 ("v_max", [:n_buses]),
					 ("pg_min", [:n_gens, :n_ext]),
					 ("pg_max", [:n_gens, :n_ext]),
					 ("qg_min", [:n_gens, :n_ext]),
					 ("qg_max", [:n_gens, :n_ext]),
					 ("p_fr_max", [:n_branches]),
					 ("p_to_max", [:n_branches]),
					 ("q_fr_max", [:n_branches]),
					 ("q_to_max", [:n_branches]),
					 ("pl", [:n_loads]),
					 ("ql", [:n_loads]),
					 ("pg", [:n_gens, :n_ext]),
					 ("qg", [:n_gens, :n_ext]),
					 ("v_bus", [:n_buses]),
					 ("vm_gen", [:n_gens, :n_ext]),
					 ("vm", [:n_buses]),
					 ("va", [:n_buses]),
					 ("p_fr", [:n_branches]),
					 ("p_to", [:n_branches]),
					 ("q_fr", [:n_branches]),
					 ("q_to", [:n_branches]),
					 ])

end
