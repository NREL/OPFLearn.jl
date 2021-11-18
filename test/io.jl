@testset "test result csv" begin
	function test_csv_results(results, filename::AbstractString, filedir::AbstractString)
		file_tmp = joinpath(filedir, filename)
		file_data = DelimitedFiles.readdlm(file_tmp, ',')
		
		num_samples = size(results["inputs"]["pd"], 1)
		input_size = sum([size(x, 2) for x in values(results["inputs"])])
		output_size = sum([size(x, 2) for x in values(results["outputs"])])
		dual_size = sum([size(x, 2) for x in values(results["duals"]) if x isa Array]) - 1 # UAS not a var
		
		@test (size(file_data, 1) - 1) == num_samples
		@test size(file_data, 2) == (input_size + output_size + dual_size)
		rm(file_tmp)
		@test true
	end
	
    @testset "5-bus case file csv check" begin
		save_order = vcat(OPFLearn.DEFAULT_INPUTS, OPFLearn.DEFAULT_OUTPUTS, OPFLearn.DEFAULT_DUALS)
		data_dir = "data"
		net_file = "pglib_opf_case5_pjm.m"
		K = 10
		results = create_samples(net_file, K, net_path=data_dir)
        file_name = "TEMP_"*net_file*"_"*"dataset"
		save_results_csv(results, file_name, save_order=save_order, dir=data_dir)
		test_csv_results(results, file_name*".csv", data_dir)
	end
	
	@testset "5-bus case file csv check with specified vars" begin
		input_vars = ["pd", "qd"]
		output_vars = ["p_gen", "q_gen"]
		dual_vars = ["v_max"]
		save_order = vcat(input_vars, output_vars, dual_vars)
		data_dir = "data"
		net_file = "pglib_opf_case5_pjm.m"
		K = 10
		results = create_samples(net_file, K, net_path=data_dir, input_vars=input_vars, 
							     output_vars=output_vars, dual_vars=dual_vars)
        file_name = "TEMP_"*net_file*"_"*"dataset"
		save_results_csv(results, file_name, save_order=save_order, dir=data_dir)
		test_csv_results(results, file_name*".csv", data_dir)
	end
end
