#!/usr/bin/env julia

println("[==== STARTING BUILD ====]")

import Pkg
using PackageCompiler

projdir = dirname(PROGRAM_FILE)
Pkg.activate(projdir)
Pkg.resolve()
Pkg.instantiate(verbose=true)

cd(projdir) do
	isdir("build") && rm("build", recursive=true, force=true)
	
	println("[==== STARTING COMPILATION ====]")
	create_app(".", "build/SatoriCLI", precompile_execution_file="precompile_app.jl")
	println("[==== COMPILATION FINISHED ====]")
	
	# The rest of this file is needed only because of a bug that occurs with PackageCompiler.jl
	
	sofiles = String[]
	
	for filename in readdir("build/SatoriCLI/lib/julia")
		filepath = joinpath("build/SatoriCLI/lib/julia", filename)
		if islink(filepath) && startswith(readlink(filepath), "../")
			dest = joinpath("build/SatoriCLI/lib/julia/", readlink(filepath))
			while islink(dest)
				push!(sofiles, dest |> basename)
				dest = joinpath("build/SatoriCLI/lib/", readlink(dest))
			end
			occursin("pcre", filename) && println("after while, dest=$dest")
			push!(sofiles, dest |> basename)
		end
	end

	for filename in readdir("build/SatoriCLI/lib")
		filepath = joinpath("build/SatoriCLI/lib", filename)
		occursin("julia", filename) && continue
		isdir(filepath) && rm(filepath, recursive=true, force=true)
		
		if !(filename in sofiles)
			rm(filepath, force=true)
		end
	end
end

println("[==== BUILD FINISHED ====]")
