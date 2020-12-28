module SatoriCLI

using Dates: format
import Gumbo
include("Satori.jl"); using .Satori

mutable struct Options
	color:: Bool
	cache:: Bool
	remember:: Bool
end

opts = Options(stdout isa Base.TTY, true, true)

function julia_main():: Cint
	try
		main()
	catch e
		if !isa(e, Tuple{Symbol, Union{AbstractString, Nothing}})
			if e isa ErrorException && e.msg == "incorrect login credentials"
				println("Incorrect login credentials" |> red)
				return 1
			else
				println(stderr, "Unknown error" |> red)
				rethrow()
			end
		elseif e[1] == :unknown_option
			println(stderr, red("Unknown option:") * ' ' * yellow(e[2]))
		elseif e[1] == :no_cmd
			println(stderr, "No command given" |> red)
		elseif e[1] == :unknown_cmd
			println(stderr, red("Unknown command:") * ' ' * yellow(e[2]))
		elseif e[1] == :cmd_usage
			println(stderr, red("Usage:") * ' ' * yellow("satori-cli [options] " * e[2]))
		elseif e[1] == :submit_file_not_found
			println(stderr, red("File not found:") * ' ' * yellow(e[2]))
		else
			println(stderr, "Unknown error" |> red)
			rethrow()
		end
		return 2
	end
	return 0
end

unknown_option_error(option:: AbstractString) = throw((:unknown_option, option))
no_cmd_error() = throw((:no_cmd, nothing))
unknown_cmd_error(cmd:: AbstractString) = throw((:unknown_cmd, cmd))
cmd_usage_error(msg:: AbstractString) = throw((:cmd_usage, msg))
submit_file_not_found_error(filepath:: AbstractString) = throw((:submit_file_not_found, filepath))

function main()
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
	elseif cmd == :submit
		submit_cmd(cmdargs)
	elseif cmd == :login
		login_cmd(cmdargs)
	elseif cmd == :forget
		forget_cmd(cmdargs)
	end
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
		cmd_usage_error("contests (joined|pending|other)")
	end
	
	for con in contests
		local name = con.name
		local desc = con.description
		
		print(rpad(con.id, 8) |> blue)
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
	contest_id == -1 && cmd_usage_error("news <contest>")
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
	contest_id == -1 && cmd_usage_error("problems <contest>")
	local problems = get_contest_problems(client, contest_id)
	
	local maxcodelen = maximum(p -> p.code |> length, problems) + 2
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

function submit_cmd(args:: AbstractVector{String})
	local errmsg = "submit <contest> : <problem> : <filepath>"
	client_login(client)
	
	local contest_id, idx = parse_contest(args)
	(contest_id == -1 || idx > length(args)) && cmd_usage_error(errmsg)
	
	local problem_id, idx_ = parse_problem(contest_id, args[idx+1:end])
	idx += idx_
	(problem_id == -1 || idx > length(args)-1) && cmd_usage_error(errmsg)
	
	local filepath = args[idx+1]
	!isfile(filepath) && submit_file_not_found_error(filepath)
	
	make_submit(client, contest_id, problem_id, filepath)
	
	println("Submitted $filepath." |> green)
end

function login_cmd(args:: AbstractVector{String})
	client_login(client)
	println("Logged in successfully with username $(client.username)." |> green)
end

function forget_cmd(args:: AbstractVecotr{String})
	rm(configdir * "/cred", force=true)
	println("Deleted the credentials file." |> green)
end

function command(idx:: Integer):: Symbol
	# we know that this index exists, because of how options() behaves
	local cmd = ARGS[idx]
	startswith("contests", cmd) && return :contests
	startswith("news", cmd) && return :news
	startswith("problems", cmd) && return :problems
	startswith("submit", cmd) && return :submit
	startswith("login", cmd) && return :login
	startswith("forget", cmd) && return :forget
	# etc...
	unknown_cmd_error(cmd)
end

function password_prompt():: String
	# TODO: do what read -s does
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
	login, pass
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
	user, pass
end

# returns (contest id or -1 if no contest matched, possible next argument index)
function parse_contest(args:: AbstractVector{String}):: Tuple{Int, Integer}
	if args |> length == 0
		return -1, 0
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

function parse_problem(contest_id:: Int, args:: AbstractVector{String}):: Tuple{Int, Integer}
	if args |> length == 0
		return -1, 0
	elseif match(r"^\d+$"a, args[1]) !== nothing
		return parse(Int, args[1]), 2
	else
		client_login(client)
		local problems = get_contest_problems(client, contest_id)
		local i = 0
		for prob in problems
			i = 0
			local matched = 0
			local lower_series = lowercase(prob.series_name)
			local lower_name = lowercase(prob.name)
			local lower_code = lowercase(prob.code)
			for arg in args
				i += 1
				arg == ":" && (matched += 1; break)
				local lower_arg = lowercase(arg)
				local series_find = findfirst(lower_arg, lower_series)
				local name_find = findfirst(lower_arg, lower_name)
				local code_find = findfirst(lower_arg, lower_code)
				(series_find !== nothing || name_find !== nothing || code_find !== nothing) && (matched += 1)
			end
			i == matched && return prob.id, i
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
			unknown_option_error(arg)
		end
	end
	# if we get here that means no command was given
	no_cmd_error()
end

end # module
