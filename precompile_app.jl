# This file is used when building SatoriCLI using PackageCompiler.jl

include("src/SatoriCLI.jl")

using .SatoriCLI: black, red, green, yellow, blue, magenta, cyan, white

open((@__DIR__) * "/precompile_in.txt") do io
	global keywords = split(readline(io))
	global contest_id = readline(io)
	global problem_id = readline(io)
	global file = readline(io)
	global user = readline(io)
	global pass = readline(io)
end


ENV["XDG_CONFIG_HOME"] = (@__DIR__) * "/build/.configdir"
ENV["XDG_CACHE_HOME"] = (@__DIR__) * "/build/.cachedir"


mkpath(ENV["XDG_CONFIG_HOME"])
open(ENV["XDG_CONFIG_HOME"] * "/cred", "w") do io
	println(io, user)
	println(io, pass)
end
chmod(ENV["XDG_CONFIG_HOME"] * "/cred", 0o600)


empty!(ARGS)
push!(ARGS, "help")
SatoriCLI.julia_main()

empty!(ARGS)
push!(ARGS, "version")
SatoriCLI.julia_main()

empty!(ARGS)
push!(ARGS, "-nocolor", "-remember", "login")
SatoriCLI.julia_main()

empty!(ARGS)
push!(ARGS, "-color", "-cache", "contests")
SatoriCLI.julia_main()

empty!(ARGS)
push!(ARGS, "news", keywords...)
SatoriCLI.julia_main()

empty!(ARGS)
push!(ARGS, "contests")
SatoriCLI.julia_main()

empty!(ARGS)
push!(ARGS, "problems", contest_id)
SatoriCLI.julia_main()

empty!(ARGS)
push!(ARGS, "problems", contest_id)
SatoriCLI.julia_main()

empty!(ARGS)
push!(ARGS, "submit", contest_id, ":", problem_id, ":", file)
SatoriCLI.julia_main()

empty!(ARGS)
push!(ARGS, "prof")
SatoriCLI.julia_main()

empty!(ARGS)
push!(ARGS, "-nocache", "-noremember", "forget")
SatoriCLI.julia_main()


rm.([ENV["XDG_CONFIG_HOME"], ENV["XDG_CACHE_HOME"]], recursive=true)
