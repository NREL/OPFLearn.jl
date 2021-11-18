# Load and save results, statistics and run parameters
function save_results_csv(results::Dict, file_name; save_order=DEFAULT_SAVE_ORDER, dir="")
	AC_inputs = results["inputs"]
	AC_outputs = results["outputs"]
	duals = results["duals"]
	return save_results_csv(AC_inputs, AC_outputs, duals, file_name, save_order=save_order, dir=dir)
end


""" 
Saves the AC\\_output, AC\\_input, duals to a csv file
"""
function save_results_csv(AC_inputs, AC_outputs, duals, file_name; save_order=DEFAULT_SAVE_ORDER, dir="")

	data = results_to_array(AC_inputs, AC_outputs, duals, save_order=save_order, header=false, imag_j=true)
	
	save_path = joinpath(dir, file_name*".csv")
	
	#TASK: Create file directory automatically to save files?
	if isfile(save_path)  # File already exists append data to it
		open(save_path, "a") do io
		writedlm(io, data, ',')
		end
	else  # Build header for network and create new file
		header = build_header(AC_inputs, AC_outputs, duals, save_order)
		data = vcat(header, data)
		writedlm(save_path, data, ',')
	end
end


""" 
Saves the given sample to the given csv file, appending it to the end of the file.
"""
function save_sample_csv(x, results, file_name, save_order, dual_vars; dir="")
	# Gen. & Ext. and Dual Results
	primal_vals, dual_vals = results

    # Load results
	new_AC_inputs = extract_load(x)
	
    # Duals results
	dual_vals["unique_active_sets"] = extract_active_set(dual_vals, dual_vars)
	
	save_results_csv(new_AC_inputs, primal_vals, dual_vals, file_name, save_order=save_order, dir=dir)
end


""" 
Builds the header as a new row to add to a data array with input, output, then dual data.
The order of the header is dictated by the variables in the save_order argument with each
element of a variable becoming a single column. Uses element labels to determine the type 
of element the result variable refers to. 
"""
function build_header(AC_inputs, AC_outputs, duals, save_order)
	header = []
	
	all_data = merge(AC_inputs, AC_outputs, duals)
	
	# Remove any keys in save_order that are not in the given results
	all_data_keys = keys(all_data)
	matched_label_indxs = [key in all_data_keys for key in save_order]
	save_order = save_order[matched_label_indxs]
	
	for key in save_order
		element = ELEMENT_LABELS[key]
		append!(header, ["$(element)$(i):"*string(key) for i in 1:size(all_data[key],2)])
	end

	return reshape(header,(1,length(header)))
end


""" 
Saves the A and b matrices defining the polytope Ax < b to two seperate comma 
delimited csv files.
"""
function save_polytope(A, b, file_name; dir="")
    save_path_A = joinpath(dir, file_name * "_A" * ".csv")
    save_path_b = joinpath(dir, file_name * "_b" * ".csv")

    writedlm(save_path_A, A, ',')
    writedlm(save_path_b, b, ',')
end


""" 
Saves an infeasibility certificate by appending new rows for the A and b matrices
to csv files. If these csv files do not already exist then calls save_polytope 
to save the entire A and b matrices in new csv files.
"""
function save_cert(A, b, file_name; dir="")
	A_last = A[end, :]'
	b_last = b[end, :]
	
    save_path_A = joinpath(dir, file_name * "_A" * ".csv")
    save_path_b = joinpath(dir, file_name * "_b" * ".csv")
	
	if isfile(save_path_A) & isfile(save_path_b)  # File already exists append data to it
		for (x, save_path) in zip((A_last, b_last), (save_path_A, save_path_b))
			open(save_path, "a") do io
				writedlm(io, x, ',')
			end
		end
	else  # Build header for network and create new file
		save_polytope(A, b, file_name, dir=dir)
	end
end


""" 
Saves the last iteration of level 1 stats to a csv file.
If the csv file does not already exist then calls save_stats
to save the stats data with a header to a new csv file.
"""
function save_stats(stats, file_name; dir="")
    save_path = joinpath(dir, file_name * ".csv")
	
	stat_labels = add_dim_h(sort(collect(keys(stats))))
	
	if stats[stat_labels[1]] isa Array && size(stats[stat_labels[1]], 1) > 1  # More than one iteration of data
		data = stats[stat_labels[1]]
	else
		data = [stats[stat_labels[1]]]
	end
	saved_stat_labels = [stat_labels[1]]
	for stat_label in stat_labels[2:end]
		if !(stats[stat_label] isa Dict)
			push!(saved_stat_labels, stat_label)
			data = hcat(data, stats[stat_label])
		end
	end
	saved_stat_labels = add_dim_h(saved_stat_labels)
	
	if isfile(save_path) # File already exists append data to it
		open(save_path, "a") do io
		writedlm(io, data, ',')
		end
	else  # Create new file with header
		stat_data = vcat(saved_stat_labels, data)
		writedlm(save_path, stat_data, ',')
	end
end

"Makes an array, x, have a second dimension and be vertically oriented"
add_dim_v(x::Array) = reshape(x, (size(x)...,1))

"Makes an array, x, have a second dimension and be horizontally oriented"
add_dim_h(x::Array) = reshape(x, (1, size(x)...))
