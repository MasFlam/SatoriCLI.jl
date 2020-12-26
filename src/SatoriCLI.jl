module SatoriCLI

using Dates: format
import Gumbo
include("Satori.jl"); using .Satori

const USAGE = "satori [options] <command> [args]"

mutable struct Options
	color:: Bool
	cache:: Bool
end

opts = Options(stdout isa Base.TTY, true)

function julia_main():: Cint
	global client = nothing
	global configdir = nothing
	global cachedir = nothing
	
	atexit() do
		client !== nothing && client_logout(client)
	end
	
	local idx = options()
	local cmd = command(idx)
	idx += 1
	local cmdargs = ARGS[idx:end]
	
	global configdir = get(ENV, "XDG_CONFIG_HOME", homedir() * "/.config/satori-cli")
	global cachedir = get(ENV, "XDG_CACHE_HOME", homedir() * "/.cache/satori-cli")
	mkpath.([configdir, cachedir], mode=0o755)
	
	global client = new_client(get_login_credentials()...; login=false)
	
	if cmd == :contests
		contests_cmd(cmdargs)
	elseif cmd == :news
		news_cmd(cmdargs)
	elseif cmd == :problems
		problems_cmd(cmdargs)
	end
	
	return 0
end

function contests_cmd(args:: AbstractVector{String})
	client_login(client)
	local contests = get_contests(client)
	
	if args |> length == 0 || args[1] == "all"
		# do nothing
	elseif args[1] == "joined"
		filter!(c -> c.joined, contests)
	elseif args[1] == "pending"
		filter!(c -> c.pending, contests)
	elseif args[1] == "other"
		filter!(c -> !c.joined, contests)
	else
		usage_exit()
	end
	
	for con in contests
		local name = con.name
		local desc = con.description
		
		print(name |> cyan)
		desc |> length != 0 && print("  -  $desc")
		if con.pending
			print("  (pending)" |> yellow)
		elseif con.joined
			print("  (joined)" |> green)
		end
		println()
	end
end

function news_cmd(args:: AbstractVector{String})
	client_login(client)
	local contest_id, idx = parse_contest(args)
	contest_id == -1 && usage_exit()
	local news = get_contest_news(client, contest_id)
	
	for n in news
		local datetime = format(n.datetime, "yyyy-mm-dd HH:MM:SS")
		println(n.title |> cyan)
		println(datetime |> yellow)
		# TODO: display this well somehow...
		Gumbo.prettyprint(Gumbo.parsehtml(n.content).root[2][1])
		println()
	end
end

function problems_cmd(args:: AbstractVector{String})
	client_login(client)
	local contest_id, idx = parse_contest(args)
	contest_id == -1 && usage_exit()
	local problems = get_contest_problems(client, contest_id)
	
	local maxcodelen = maximum(p -> p.name |> length, problems)
	local prev_series_name = nothing
	for prob in problems
		if prob.series_name != prev_series_name
			println(prob.series_name |> magenta)
			println('=' ^ length(prob.series_name) |> magenta)
			println()
			prev_series_name = prob.series_name
		end
		local id = rpad(prob.id, 8)
		local code = rpad('[' * prob.code * ']', maxcodelen)
		println("$(id |> blue) $(code |> cyan) $(prob.name |> green)")
		prob.note |> length > 0 && println(prob.note)
		println()
	end
end

function command(idx:: Integer):: Symbol
	# we know that this index exists, because of how options() behaves
	local cmd = ARGS[idx]
	startswith("contests", cmd) && return :contests
	startswith("news", cmd) && return :news
	startswith("problems", cmd) && return :problems
	# etc...
	usage_exit()
end

function usage_exit()
	println(stderr, "Usage: " * USAGE)
	exit(2)
end

function password_prompt():: String
	# TODD: do what read -s does
	return readline()
end

black(s):: AbstractString   = opts.color ? "\e[30m" * s * "\e[39m" : string(s)
red(s):: AbstractString     = opts.color ? "\e[31m" * s * "\e[39m" : string(s)
green(s):: AbstractString   = opts.color ? "\e[32m" * s * "\e[39m" : string(s)
yellow(s):: AbstractString  = opts.color ? "\e[33m" * s * "\e[39m" : string(s)
blue(s):: AbstractString    = opts.color ? "\e[34m" * s * "\e[39m" : string(s)
magenta(s):: AbstractString = opts.color ? "\e[35m" * s * "\e[39m" : string(s)
cyan(s):: AbstractString    = opts.color ? "\e[36m" * s * "\e[39m" : string(s)
white(s):: AbstractString   = opts.color ? "\e[37m" * s * "\e[39m" : string(s)

function ask_credentials():: Tuple{String, String}
	print("Satori login: ")
	local login = readline()
	print("Satori password: ")
	local pass = password_prompt()
	return login, pass
end

function get_login_credentials():: Tuple{String, String}
	local user, pass = nothing, nothing
	if !isfile(configdir * "/cred")
		user, pass = ask_credentials()
		if opts.remember
			open(configdir * "/cred", "w") do io
				write(io, user * '\n')
				write(io, pass * '\n')
			end
			chmod(configdir * "/cred", 0o600)
		end
	else
		local arr = readlines(configdir * "/cred")
		user = arr[1]
		pass = arr[2]
	end
	return user, pass
end

# returns (contest id or -1 if no contest matched, possible next argument index)
function parse_contest(args:: AbstractVector{String}):: Tuple{Int, Integer}
	if args |> length == 0
		usage_exit()
	elseif match(r"^\d+$"a, args[1]) !== nothing
		return parse(Int, args[1]), 2
	else
		client_login(client)
		local contests = get_contests(client)
		local i = 0
		for con in contests
			i = 0
			local matched = 0
			local lowername = lowercase(con.name)
			local lowerdesc = lowercase(con.description)
			for arg in args
				i += 1
				arg == ":" && (matched += 1; break)
				local lowerarg = lowercase(arg)
				local namefind = findfirst(lowerarg, lowername)
				local descfind = findfirst(lowerarg, lowerdesc)
				(namefind !== nothing || descfind !== nothing) && (matched += 1)
			end
			i == matched && return con.id, i
		end
		return -1, i
	end
end

# returns the index of the <command> (guarantees it's a valid index into ARGS)
function options():: Integer
	local i = 0
	for arg in ARGS
		i += 1
		arg[1] != '-' && return i
		if arg == "-remember"
			opts.remember = true
		elseif arg == "-noremember"
			opts.remember = false
		elseif arg == "-cache"
			opts.cache = true
		elseif arg == "-nocache"
			opts.cache = false
		elseif arg == "-color"
			opts.color = true
		elseif arg == "-nocolor"
			opts.color = false
		else
			usage_exit()
		end
	end
	# if we get here that means no command was given
	usage_exit()
end

end # module
