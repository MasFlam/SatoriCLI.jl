module Satori

export Client,
	Contest,
	ContestNews,
	Problem,
	Result,
	UserProfile,
	new_client,
	client_login,
	client_logout,
	get_contests,
	get_contest_news,
	get_contest_problems,
	get_contest_results_count,
	get_contest_results,
	get_problem_html,
	get_problem_pdf,
	make_submit,
	get_user_profile

import HTTP, Gumbo
using HTTP: Cookie
using Gumbo: parsehtml, tag, text
using URIs: escapeuri
using Dates: DateTime, @dateformat_str

mutable struct Client
	username:: AbstractString
	password:: AbstractString
	cookiejar:: Dict{String, Set{Cookie}}
	relogin:: Bool
	logged_in:: Bool
end

struct Contest
	id:: Int
	name:: AbstractString
	description:: AbstractString
	managed:: Bool
	joined:: Bool
	pending:: Bool
end

struct ContestNews
	title:: AbstractString
	datetime:: DateTime
	content:: AbstractString
end

struct Problem
	id:: Int
	contest_id:: Int
	series_name:: AbstractString
	code:: AbstractString
	name:: AbstractString
	note:: AbstractString
end

struct Result
	id:: Int
	contest_id:: Int
	problem_code:: AbstractString
	datetime:: DateTime
	status:: AbstractString
end

struct UserProfile
	first_name:: AbstractString
	last_name:: AbstractString
	affiliation:: AbstractString
	confirmed:: Bool
end


function Base.show(io:: IO, client:: Client)
	print(io, client |> typeof)
	print(io, "($(client.username), $('*' ^ max(length(client.password), 10)), relogin=$(client.relogin), logged_in=$(client.logged_in))")
end

function Base.show(io:: IO, news:: ContestNews)
	println(io, news.title)
	println(io, news.datetime)
	Gumbo.prettyprint(io, (news.content |> parsehtml).root[2][1])
end


const URL_BASE = "https://satori.tcs.uj.edu.pl"

function query_satori(client:: Client, method, path, headers, body; kws...):: HTTP.Response
	local hdrs = Dict()
	body === nothing && (hdrs["Content-Length"] = 0)
	local resp = HTTP.request(
		method,
		URL_BASE * string(path),
		Dict(hdrs..., headers...),
		body,
		redirect = false,
		cookies = true,
		cookiejar = client.cookiejar,
		#status_exception = false,
		kws...
	)
	
	# if it redirects us to the login page that means our session ended or we're not logged in at all
	if 300 <= resp.status < 400 && any(h -> h[1] == "Location" && startswith(URL_BASE * "/login", h[2]), resp.headers)
		if client.relogin
			client_login(client, force=true)
			return query_satori(client, method, path, headers, body; kws...)
		else
			error("not logged in and relogin is off")
		end
	end
	
	resp
end


function new_client(
	username:: AbstractString,
	password:: AbstractString;
	login:: Bool = true,
	relogin:: Bool = true
):: Client
	local client = Client(username, password, Dict{String, Set{Cookie}}(), relogin, false)
	login && client_login(client)
	client
end

function client_login(client:: Client; force:: Bool = false)
	if !client.logged_in || force
		local resp = query_satori(
			client,
			:POST,
			"/login",
			[],
			"login=$(client.username |> escapeuri)&password=$(client.password |> escapeuri)"
		)
		# if the login is successful we get redirected to /news by default with a 302
		resp.status == 200 && error("incorrect login credentials")
	end
	client.logged_in = true
end

function client_logout(client:: Client; force:: Bool = false)
	(client.logged_in || force) && query_satori(
		client,
		:GET,
		"/logout",
		[],
		nothing
	)
	client.logged_in = false
end

function get_contests(client:: Client):: Vector{Contest}
	local resp = query_satori(
		client,
		:GET,
		"/contest/select",
		[],
		nothing
	)
	
	local content_elem = parsehtml(String(resp.body)).root[2][1][2][1][1][1][2][1]
	
	local managed_elem = nothing
	local joined_elem = nothing
	local other_elem = nothing
	
	for i in 1:3:length(content_elem.children)
		tag(content_elem[i]) == :hr && break
		local s = text(content_elem[i])
		if s == "Managed contests:"
			managed_elem = content_elem[i+1][1]
		elseif s == "Joined contests:"
			joined_elem = content_elem[i+1][1]
		elseif s == "Other contests:"
			other_elem = content_elem[i+1][1]
		end
	end
	
	local contests = Contest[]
	
	managed_elem !== nothing && for tr in managed_elem.children[2:end]
		push!(contests, Contest(
			parse(Int, match(r"/contest/(\d+)", tr[1][1].attributes["href"])[1]),
			tr[1] |> text,
			tr[2] |> text,
			true,
			false,
			false
		))
	end
	
	joined_elem !== nothing && for tr in joined_elem.children[2:end]
		push!(contests, Contest(
			parse(Int, match(r"/contest/(\d+)", tr[1][1].attributes["href"])[1]),
			tr[1] |> text,
			tr[2] |> text,
			false,
			true,
			tr[3].children |> !isempty
		))
	end
	
	other_elem !== nothing && for tr in other_elem.children[2:end]
		push!(contests, Contest(
			parse(Int, match(r"/contest/(\d+)", tr[1][1].attributes["href"])[1]),
			tr[1] |> text,
			tr[2] |> text,
			false,
			false,
			false
		))
	end
	
	contests
end

get_contest_news(client:: Client, contest:: Contest):: Vector{ContestNews} =
	get_contest_news(client, contest.id)

function get_contest_news(client:: Client, contest_id:: Int):: Vector{ContestNews}
	local resp = query_satori(
		client,
		:GET,
		"/contest/$contest_id/news",
		[],
		nothing
	)
	
	local content_elem = parsehtml(String(resp.body)).root[2][1][2][1][1][1][2][1]
	local contest_news = ContestNews[]
	
	for news_elem in content_elem.children
		local header = news_elem[1][1][1]
		local title = header[1][1] |> text
		local datetime = DateTime(header[2][1] |> text, dateformat"y-m-d, H:M:S")
		local content = news_elem[1][1][2][1][1] |> string
		push!(contest_news, ContestNews(title, datetime, content))
	end
	
	contest_news
end

get_contest_problems(client:: Client, contest:: Contest):: Vector{Problem} =
	get_contest_problems(client, contest.id)

function get_contest_problems(client:: Client, contest_id:: Int):: Vector{Problem}
	local resp = query_satori(
		client,
		:GET,
		"/contest/$contest_id/problems",
		[],
		nothing
	)
	
	local content_elem = parsehtml(String(resp.body)).root[2][1][2][1][1][1][2][1][1]
	local problems = Problem[]
	
	for i in 1:div(length(content_elem.children), 2)
		local series_name = text(content_elem[2i - 1][1])[1:end-1] |> strip
		local tbody = content_elem[2i][1][1]
		for tr in tbody.children[2:end]
			local idstr = match(r"/contest/\d+/problems/(\d+)", tr[2][1].attributes["href"])[1]
			local code = tr[1] |> text
			local name = tr[2] |> text
			local note = tr[4] |> text
			push!(problems, Problem(
				parse(Int, idstr),
				contest_id,
				series_name,
				code,
				name,
				note
			))
		end
	end
	
	problems
end

get_contest_results_count(client:: Client, contest:: Contest):: Integer =
	get_contest_results_count(client, contest.id)

function get_contest_results_count(client:: Client, contest_id:: Int):: Integer
	local resp = query_satori(
		client,
		:GET,
		"/contest/$contest_id/results?results_limit=1",
		[],
		nothing
	)
	
	local pages_div = parsehtml(String(resp.body)).root[2][1][2][1][1][1][2][1][4]
	pages_div.children |> length
end

get_contest_results(
	client:: Client,
	contest:: Contest;
	pagesize:: Integer = 30,
	pagenum:: Integer = 1
):: Vector{Vector{Result}, Integer} = get_contest_results(client, contest.id, pagesize=pagesize, pagenum=pagenum)

# returns ([results...], pagecount)
function get_contest_results(
	client:: Client,
	contest_id:: Int;
	pagesize:: Integer = 30,
	pagenum:: Integer = 1
):: Tuple{Vector{Result}, Integer}
	local resp = query_satori(
		client,
		:GET,
		"/contest/$contest_id/results?results_limit=$pagesize&results_page=$pagenum",
		[],
		nothing
	)
	
	local div = parsehtml(String(resp.body)).root[2][1][2][1][1][1][2][1]
	local tbody = div[2][1]
	local results = Result[]
	local pagecount = div[4].children |> length
	
	for tr in tbody.children[2:end]
		local idstr = tr[1] |> text
		local problem_code = tr[2] |> text
		local datetime = DateTime(tr[3] |> text, dateformat"y-m-d H:M:S")
		local status = tr[4] |> text
		push!(results, Result(
			parse(Int, idstr),
			contest_id,
			problem_code,
			datetime,
			status
		))
	end
	
	results, pagecount
end

get_problem_html(client:: Client, problem:: Problem):: AbstractString =
	get_problem_html(client, problem.contest_id, problem.id)

function get_problem_html(client:: Client, contest_id:: Int, problem_id:: Int):: AbstractString
	local resp = query_satori(
		client,
		:GET,
		# These are also found where the PDFs are, just replace _pdf with _html in the URL.
		# That would yield the contest id unneccessary for fetching problem HTML. Also, response
		# from that is way faster, but the problem is that links/images have their URLs
		# set differently in that HTML, and I would have to figure out how to fix those...
		"/contest/$contest_id/problems/$problem_id",
		[],
		nothing
	)
	
	local elem = parsehtml(String(resp.body)).root[2][1][2][1][1][1][2][1][2]
	elem |> string
end

get_problem_pdf(client:: Client, problem:: Problem):: Vector{UInt8} =
	get_problem_pdf(client, problem.id)

function get_problem_pdf(client:: Client, problem_id:: Int):: Vector{UInt8}
	local resp = query_satori(
		client,
		:GET,
		# Interesting discovery: the part after _pdf/ doesn't matter. If it ends with an extension
		# like .pdf or .dvi, its Content-Type is according. Otherwise it is text/html.
		# Also when .pdf or .dvi is present, it gets sent in Base64 format, otherwise in plaintext.
		"/view/ProblemMapping/$problem_id/statement_files/_pdf/ld",
		[],
		nothing
	)
	
	resp.body
end

make_submit(client:: Client, problem:: Problem, args...) =
	make_submit(client, problem.contest_id, problem.id, args...)

make_submit(client:: Client, contest_id:: Int, problem_id:: Int, filepath:: AbstractString) =
	make_submit(client, contest_id, problem_id, read(filepath, String), basename(filepath))

function make_submit(
	client:: Client,
	contest_id:: Int,
	problem_id:: Int,
	code:: AbstractString,
	filename:: AbstractString
)
	#local boundary = "--ld123--" * string(rand(1_000_000:1_000_000_000))
	local boundary = "---------------------------202420241229766659513730330414"
	local resp = query_satori(
		client,
		:POST,
		"/contest/$contest_id/submit",
		["Content-Type" => "multipart/form-data; boundary=$boundary"],
			"--$boundary\r\n" *
			"Content-Disposition: form-data; name=\"problem\"\r\n\r\n" *
			"$(string(problem_id))\r\n" *
			"--$boundary\r\n" *
			"Content-Disposition: form-data; name=\"codefile\"; filename=\"$filename\"\r\n" *
			"Content-Type: text/plain\r\n\r\n" *
			"$code\r\n" *
			"--$boundary--\r\n"
	)
end

function get_user_profile(client:: Client):: UserProfile
	local resp = query_satori(
		client,
		:GET,
		"/profile",
		[],
		nothing
	)
	
	local tbody = parsehtml(String(resp.body)).root[2][1][2][1][1][1][2][1][2][1][1]
	local first_name = tbody[1][2][1].attributes["value"]
	local last_name = tbody[2][2][1].attributes["value"]
	local confirmed = tbody[2][2].children |> length > 1
	# why doesn't Gumbo.HTMLElement have lastindex()?
	local affiliation = tbody[6][2][1].attributes["value"]
	
	UserProfile(first_name, last_name, affiliation, confirmed)
end

end # module
