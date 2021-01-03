module SatoriCLI

import Gumbo
import Dates
using Dates: DateTime, @dateformat_str, format, now,
	Period, Second, Minute, Hour, Day, Week
using URIs: parse_uri
include("Satori.jl"); using .Satori

const SATORI_CLI_VERSION = v"0.1.0"

const COPYRIGHT = """
Copyright (C) 2020-2021 Łukasz "MasFlam" Drukała
Licensed under the GNU GPL version 3, available here: https://www.gnu.org/licenses/gpl-3.0.html
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
"""

mutable struct Options
	color:: Bool
	cache:: Bool
	remember:: Bool
end

mutable struct Config
	contests_cache_ttl:: Period
	contest_news_cache_ttl:: Period
	contest_problems_cache_ttl:: Period
	user_profile_cache_ttl:: Period
end

opts = nothing
config = nothing

function julia_main():: Cint
	global opts = Options(stdout isa Base.TTY, true, true)
	global config = Config(Hour(4), Hour(6), Minute(30), Day(1))
	try
		main()
	catch e
		if !isa(e, Tuple{Symbol, Any})
			if e isa ErrorException && e.msg == "incorrect login credentials"
				println("Incorrect login credentials" |> red)
				return 1
			else
				println(stderr, "Unknown error" |> red)
				showerror(stderr, e)
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
		elseif e[1] == :invalid_period
			println(stderr, red("Invalid period:") * ' ' * yellow(e[2]))
		elseif e[1] == :read_config
			println(stderr, red("Error reading config at line ") * yellow(e[2][1]) * red(": ") * yellow(e[2][2]))
		else
			println(stderr, "Unknown error" |> red)
			showerror(stderr, e)
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
invalid_period_error(msg:: AbstractString) = throw((:invalid_period, msg))
read_config_error(lineno:: Integer, msg:: AbstractString) = throw((:read_config, (lineno, msg)))

function main()
	global client = nothing
	global configdir = nothing
	global cachedir = nothing
	
	atexit() do
		client !== nothing && client_logout(client)
	end
	
	global configdir = joinpath(get(ENV, "XDG_CONFIG_HOME", joinpath(homedir(), ".config")), "satori-cli")
	global cachedir = joinpath(get(ENV, "XDG_CACHE_HOME", joinpath(homedir(), ".cache")), "satori-cli")
	mkpath.([configdir, cachedir], mode=0o755)
	
	read_config()
	
	local idx = options()
	local cmd = command(idx)
	idx += 1
	local cmdargs = ARGS[idx:end]
	
	if cmd == :help
		help_cmd(cmdargs)
	elseif cmd == :version
		version_cmd(cmdargs)
	elseif cmd == :contests
		contests_cmd(cmdargs)
	elseif cmd == :news
		news_cmd(cmdargs)
	elseif cmd == :problems
		problems_cmd(cmdargs)
	elseif cmd == :results
		results_cmd(cmdargs)
	elseif cmd == :submit
		submit_cmd(cmdargs)
	elseif cmd == :login
		login_cmd(cmdargs)
	elseif cmd == :forget
		forget_cmd(cmdargs)
	elseif cmd == :profile
		profile_cmd(cmdargs)
	end
end

function help_cmd(args:: AbstractVector{String})
	println("SatoriCLI, version $SATORI_CLI_VERSION" |> yellow)
	println("A command line interface client for the Satori testing system." |> yellow)
	println()
	println(magenta("Usage: ") * cyan("satori-cli [options] <command> [...]"))
	println()
	println("Commands:" |> magenta)
	println("    " * cyan("help") * " - Get usage help")
	println("    " * cyan("version") * " - Get SatoriCLI version")
	println("    " * cyan("login") * " - Just log in")
	println("    " * cyan("forget") * " - Forget the remembered login credentials")
	println("    " * cyan("contests") * " - Get contest list")
	println("    " * cyan("news <contest>") * " - Get news for " * cyan("<contest>"))
	println("    " * cyan("problems <contest>") * " - Get list of problems in " * cyan("<contest>"))
	println("    " * cyan("results <contest> [: [pagesize=10]+[pagenum=1] | : <submit_id>]") * " - Get results for " * cyan("<submit_id>") * " or " * cyan("<contest>"))
	println("    " * cyan("submit <contest> : <problem> : <filepath>") * " - Submit file $(cyan("<filepath>")) to $(cyan("<problem>")) in $(cyan("<contest>"))")
	println("    " * cyan("profile") * " - Get the user profile")
	println()
	println("Commands can be shortened to their prefixes, i.e. $(cyan("c")) means $(cyan("contests")) and $(cyan("prof")) means $(cyan("profile")).")
	println(cyan("<contest>") * " - Contest ID or a list of keywords to search for")
	println(cyan("<problem>") * " - Problem ID or a list of keywords to search for")
	println()
	println("Options:" |> magenta)
	println("    $(cyan("-color"))/$(cyan("-nocolor")) - Enable/disable colored output")
	println("    $(cyan("-cache"))/$(cyan("-nocache")) - Enable/disable writing to cache")
	println("    $(cyan("-remember"))/$(cyan("-noremember")) - Enable/disable saving the login credentials")
	println()
	println("The configuration file is read line by line and each line contains a $(cyan("key: value")) pair. Lines starting with $('#' |> cyan) are ignored.")
	println(magenta("Configuration file:") * ' ' * cyan(realpath(joinpath(configdir, "config.txt"))))
	println("Valid configuration keys:" |> magenta)
	println("    " * cyan("contests_cache_ttl") * " - Duration for which to cache the contests list " * cyan("(default 4h)"))
	println("    " * cyan("contest_news_cache_ttl") * " - Duration for which to cache contest news " * cyan("(default 6h)"))
	println("    " * cyan("contest_problems_cache_ttl") * " - Duration for which to cache contest problems " * cyan("(default 30m)"))
	println("    " * cyan("user_profile_cache_ttl") * " - Duration for which to cache the user profile " * cyan("(default 1d)"))
	println("Results aren't cached since that would probably be useless.")
	println()
	print(COPYRIGHT |> yellow)
end

function version_cmd(args:: AbstractVector{String})
	println("SatoriCLI, version $SATORI_CLI_VERSION" |> yellow)
	println("A command line interface client for the Satori testing system." |> yellow)
	println()
	print(COPYRIGHT |> yellow)
end

function contests_cmd(args:: AbstractVector{String})
	local contests = get_cached_contests()
	
	if args |> isempty || args[1] == "all"
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
		print(' ')
		print(name |> cyan)
		desc |> !isempty && print("  -  $desc")
		if con.pending
			print("  (pending)" |> yellow)
		elseif con.joined
			print("  (joined)" |> green)
		end
		println()
	end
end

function news_cmd(args:: AbstractVector{String})
	local contest_id, idx = parse_contest(args)
	contest_id == -1 && cmd_usage_error("news <contest>")
	local news = get_cached_contest_news(contest_id)
	
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
	local contest_id, idx = parse_contest(args)
	contest_id == -1 && cmd_usage_error("problems <contest>")
	local problems = get_cached_contest_problems(contest_id)
	
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
		prob.note |> !isempty && println(prob.note)
		println()
	end
end

function results_cmd(args:: AbstractVector{String})
	local errmsg = "results <contest> [: [pagesize=10]+[pagenum=1] | : <submit_id>]"
	
	local contest_id, idx = parse_contest(args)
	contest_id == -1 && cmd_usage_error(errmsg)
	
	local pagesize, pagenum = nothing, nothing
	local m = nothing
	if idx == length(args)
		pagesize = 10
		pagenum = 1
	elseif (m = match(r"^(\d*)[+](\d*)$", args[idx+1])) !== nothing
		try
			pagesize = m[1] != "" ? parse(Int, m[1]) : 10
			pagenum = m[2] != "" ? parse(Int, m[2]) : 1
		catch e
			cmd_usage_error(errmsg)
		end
	elseif match(r"^\d+$", args[idx+1]) !== nothing
		# results for submit
		local submit_id = parse(Int, args[idx+1])
		@show submit_id
		error("Unimplemented!")
		# TODO: per-submit results api
		return
	else
		cmd_usage_error(errmsg)
	end
	
	# results for contest
	login()
	local results, pagecount = get_contest_results(client, contest_id, pagesize=pagesize, pagenum=pagenum)
	local maxcodelen = maximum(r -> r.problem_code |> length, results) + 2
	
	println(magenta("Results for page ") * cyan(pagenum) * magenta(" out of ") * cyan(pagecount) * magenta(':'))
	println()
	
	for res in results
		local id = rpad(res.id, 8)
		local pcode = rpad('[' * res.problem_code * ']', maxcodelen)
		local datetime = format(res.datetime, "yyyy-mm-dd HH:MM:SS")
		local status = res.status
		local fn = identity
		status == "OK" && (fn = green)
		status in ["ANS", "RTE", "TLE", "TL"] && (fn = red)
		status == "QUE" && (fn = yellow)
		status in ["CME", "EXT"] && (fn = blue)
		println(blue(id) * ' ' * cyan(pcode) * ' ' * datetime * ' ' * fn(status))
	end
end

function submit_cmd(args:: AbstractVector{String})
	local errmsg = "submit <contest> : <problem> : <filepath>"
	
	local contest_id, idx = parse_contest(args)
	(contest_id == -1 || idx > length(args)) && cmd_usage_error(errmsg)
	
	local problem_id, idx_ = parse_problem(contest_id, args[idx+1:end])
	idx += idx_
	(problem_id == -1 || idx > length(args)-1) && cmd_usage_error(errmsg)
	
	local filepath = args[idx+1]
	!isfile(filepath) && submit_file_not_found_error(filepath)
	
	login()
	make_submit(client, contest_id, problem_id, filepath)
	
	println("Submitted $filepath." |> green)
end

function login_cmd(args:: AbstractVector{String})
	login()
	println("Logged in successfully with username $(client.username)." |> green)
end

function forget_cmd(args:: AbstractVector{String})
	rm(joinpath(configdir, "cred"), force=true)
	println("Deleted the credentials file." |> green)
end

function profile_cmd(args:: AbstractVector{String})
	local profile = get_cached_user_profile()
	local user = client !== nothing ? client.username : get_login_credentials(want_password=false)[1]
	println(blue("Username:") * ' ' * cyan(user))
	println(blue("First name:") * ' ' * cyan(profile.first_name))
	println(blue("Last name:") * ' ' * cyan(profile.last_name))
	println(blue("Affiliation:") * ' ' * cyan(profile.affiliation))
	println(blue("Confirmed:") * ' ' * (profile.confirmed ? green("yes") : red("no")))
end

function command(idx:: Integer):: Symbol
	# we know that this index exists, because of how options() behaves
	local cmd = ARGS[idx]
	startswith("help", cmd) && return :help
	startswith("version", cmd) && return :version
	startswith("contests", cmd) && return :contests
	startswith("news", cmd) && return :news
	startswith("problems", cmd) && return :problems
	startswith("results", cmd) && return :results
	startswith("submit", cmd) && return :submit
	startswith("login", cmd) && return :login
	startswith("forget", cmd) && return :forget
	startswith("profile", cmd) && return :profile
	# etc...
	unknown_cmd_error(cmd)
end

function password_prompt():: String
	# TODO: do what read -s does
	return readline()
end

black(s):: AbstractString   = opts.color ? "\e[30m" * string(s) * "\e[39m" : string(s)
red(s):: AbstractString     = opts.color ? "\e[31m" * string(s) * "\e[39m" : string(s)
green(s):: AbstractString   = opts.color ? "\e[32m" * string(s) * "\e[39m" : string(s)
yellow(s):: AbstractString  = opts.color ? "\e[33m" * string(s) * "\e[39m" : string(s)
blue(s):: AbstractString    = opts.color ? "\e[34m" * string(s) * "\e[39m" : string(s)
magenta(s):: AbstractString = opts.color ? "\e[35m" * string(s) * "\e[39m" : string(s)
cyan(s):: AbstractString    = opts.color ? "\e[36m" * string(s) * "\e[39m" : string(s)
white(s):: AbstractString   = opts.color ? "\e[37m" * string(s) * "\e[39m" : string(s)

function login()
	if client === nothing
		global client = new_client(get_login_credentials()...)
	else
		client_login(client)
	end
end

function ask_credentials(; want_password:: Bool = true):: Tuple{String, Union{String, Nothing}}
	print("Satori login: ")
	local login, pass = readline(), nothing
	if want_password
		print("Satori password: ")
		pass = password_prompt()
	end
	login, pass
end

function get_login_credentials(; want_password:: Bool = true):: Tuple{String, Union{String, Nothing}}
	local user, pass = nothing, nothing
	local path = joinpath(configdir, "cred")
	if !isfile(path)
		user, pass = ask_credentials(want_password=want_password)
		if opts.remember && want_password
			open(path, "w") do io
				write(io, user * '\n')
				write(io, pass * '\n')
			end
			chmod(path, 0o600)
		end
	else
		local arr = readlines(path)
		user = arr[1]
		want_password && (pass = arr[2])
	end
	user, pass
end

# returns (contest id or -1 if no contest matched, next ':' index or last index in args)
function parse_contest(args:: AbstractVector{String}):: Tuple{Int, Integer}
	if args |> isempty
		return -1, 0
	elseif match(r"^\d+$"a, args[1]) !== nothing
		return parse(Int, args[1]), 2
	else
		local contests = get_cached_contests()
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
	if args |> isempty
		return -1, 0
	elseif match(r"^\d+$"a, args[1]) !== nothing
		return parse(Int, args[1]), 2
	else
		local problems = get_cached_contest_problems(contest_id)
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

function parse_period(str:: AbstractString):: Period
	local digits = Char[]
	local period = Second(0)
	for ch in str
		isspace(ch) && continue
		if isdigit(ch)
			push!(digits, ch)
		elseif occursin(ch, "smhdw")
			local fn = nothing
			if ch == 's'
				fn = Second
			elseif ch == 'm'
				fn = Minute
			elseif ch == 'h'
				fn = Hour
			elseif ch == 'd'
				fn = Day
			elseif ch == 'w'
				fn = Week
			else
				invalid_period_error("Unknown unit of time: '$ch'")
			end
			isempty(digits) && push!(digits, '1')
			period += Second(fn(String(digits)))
			empty!(digits)
		else
			invalid_period_error("Unexpected character: '$ch'")
		end
	end
	period
end

function get_cached_contests():: Vector{Contest}
	local contests = Contest[]
	local path = joinpath(cachedir, "contests")
	if opts.cache && isfile(path)
		open(path) do io
			local datetime = DateTime(readline(io), dateformat"y-m-d H:M:S")
			if now() - datetime < config.contests_cache_ttl
				while !eof(io)
					local id = parse(Int, readline(io))
					local name = readline(io)
					local desc = readline(io)
					local status = readline(io)
					local pending = status == "pending"
					local joined = status == "joined" || pending
					push!(contests, Contest(id, name, desc, joined, pending))
					readline(io) # consume = = = = =
				end
			end
		end
	end
	contests |> !isempty && return contests
	
	login()
	contests = get_contests(client)
	
	open(path, "w") do io
		format(io, now(), dateformat"yyyy-mm-dd HH:MM:SS")
		println(io)
		for con in contests
			println(io, con.id)
			println(io, con.name)
			println(io, con.description)
			if con.pending
				println(io, "pending")
			elseif con.joined
				println(io, "joined")
			else
				println(io, "other")
			end
			println(io, "= = = = =")
		end
	end
	
	contests
end

get_cached_contest_news(contest:: Contest):: Vector{ContestNews} =
	get_cached_contest_news(contest.id)

function get_cached_contest_news(contest_id:: Int):: Vector{ContestNews}
	local news = ContestNews[]
	local path = joinpath(cachedir, "news-$contest_id")
	if opts.cache && isfile(path)
		open(path) do io
			local datetime = DateTime(readline(io), dateformat"y-m-d H:M:S")
			if now() - datetime < config.contest_news_cache_ttl
				local title, datetime = nothing, nothing
				local lines = String[]
				while !eof(io)
					if title === nothing
						title = readline(io)
						continue
					elseif datetime === nothing
						datetime = DateTime(readline(io), dateformat"y-m-d H:M:S")
						continue
					end
					
					local line = readline(io)
					if line == "= = = = ="
						push!(news, ContestNews(title, datetime, join(lines, '\n')))
						title, datetime = nothing, nothing
						empty!(lines)
					else
						push!(lines, line)
					end
				end
			end
		end
	end
	news |> !isempty && return news
	
	login()
	news = get_contest_news(client, contest_id)
	
	open(path, "w") do io
		format(io, now(), dateformat"yyyy-mm-dd HH:MM:SS")
		println(io)
		for n in news
			println(io, n.title)
			format(io, n.datetime, dateformat"yyyy-mm-dd HH:MM:SS")
			println(io)
			println(io, n.content)
			println(io, "= = = = =")
		end
	end
	
	news
end

get_cached_contest_problems(contest:: Contest):: Vector{Problem} =
	get_cached_contest_problems(contest.id)

function get_cached_contest_problems(contest_id:: Int):: Vector{Problem}
	local problems = Problem[]
	local path = joinpath(cachedir, "problems-$contest_id")
	if opts.cache && isfile(path)
		open(path) do io
			local datetime = DateTime(readline(io), dateformat"y-m-d H:M:S")
			if now() - datetime < config.contest_problems_cache_ttl
				local series_name = nothing
				while !eof(io)
					local id = readline(io)
					if id == "= = = = ="
						series_name = readline(io)
						id = parse(Int, readline(io))
					else
						id = parse(Int, id)
					end
					local code = readline(io)
					local name = readline(io)
					local note = readline(io)
					push!(problems, Problem(id, contest_id, series_name, code, name, note))
					readline(io) # consume - - - - -
				end
			end
		end
	end
	problems |> !isempty && return problems
	
	login()
	problems = get_contest_problems(client, contest_id)
	
	open(path, "w") do io
		format(io, now(), dateformat"yyyy-mm-dd HH:MM:SS")
		println(io)
		local last_series_name = nothing
		for prob in problems
			if prob.series_name != last_series_name
				println(io, "= = = = =")
				println(io, prob.series_name)
				last_series_name = prob.series_name
			end
			println(io, prob.id)
			println(io, prob.code)
			println(io, prob.name)
			println(io, prob.note)
			println(io, "- - - - -")
		end
	end
	
	problems
end

function get_cached_user_profile():: UserProfile
	local profile = nothing
	local path = joinpath(cachedir, "profile")
	if opts.cache && isfile(path)
		open(path) do io
			local datetime = DateTime(readline(io), dateformat"y-m-d H:M:S")
			if now() - datetime < config.user_profile_cache_ttl
				local first_name = readline(io)
				local last_name = readline(io)
				local affiliation = readline(io)
				local confirmed = parse(Bool, readline(io))
				profile = UserProfile(first_name, last_name, affiliation, confirmed)
			end
		end
	end
	profile !== nothing && return profile
	
	login()
	profile = get_user_profile(client)
	
	open(path, "w") do io
		format(io, now(), dateformat"yyyy-mm-dd HH:MM:S")
		println(io)
		println(io, profile.first_name)
		println(io, profile.last_name)
		println(io, profile.affiliation)
		println(io, profile.confirmed ? '1' : '0')
	end
	
	profile
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

function read_config()
	local path = joinpath(configdir, "config.txt")
	if isfile(path)
		open(path) do io
			local lineno = 0
			while !eof(io)
				local line = readline(io)
				lineno += 1
				startswith(line, r"\s*#") && continue
				local colonpos = findfirst(':', line)
				colonpos === nothing && continue
				local key = line[begin:colonpos-1]
				local val = line[colonpos+1:end]
				
				try
					if key == "contests_cache_ttl"
						config.contests_cache_ttl = parse_period(val)
					elseif key == "contest_news_cache_ttl"
						config.contest_news_cache_ttl = parse_period(val)
					elseif key == "contest_problems_cache_ttl"
						config.contest_problems_cache_ttl = parse_period(val)
					elseif key == "user_profile_cache_ttl"
						config.user_profile_cache_ttl = parse_period(val)
					end
				catch e
					read_config_error(lineno, e[2])
				end
			end
		end
	end
end

end # module
