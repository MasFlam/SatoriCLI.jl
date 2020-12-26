# TODO:
* Set up the project to use PackageCompiler.jl

## API-related
* Auto-relogin if session's over
* Applying to contests
* ~~Submits/Results~~ **Done!**
  - ~~`Result`~~
  - ~~`get_results(client)`~~
  - ~~`get_result_details(client, contest_id, result_id)`~~
  - and pagination... ~~:( will be a Spain without the S~~ *wasn't that bad :)*
* ~~Problem content~~ **Done! Will probably poke around this though**
  - ~~`get_problem_pdf(client, problem_id)`~~
  - ~~`get_problem_html(client, problem_id)`~~
* Submitting
  - `submit(client, contest_id, problem_id, code, filename)`
* User profile
  - `UserProfile`
  - `first_name(profile)`
  - `last_name(profile)`
  - `affiliation(profile)`
  - `change_password(client[, old_password ], new_password)`
* Rankings
  - `Ranking`
  - `get_contest_rankings(client, contest_id)`
  - `get_contest_ranking(client, contest_id, ranking_id)`


## CLI-related
* ~~Contests~~ **Done!**
  - ~~retrieving & displaying contests~~
  - ~~parsing &lt;contest&gt; arguments~~
* Contest news **- semi-done**
  - ~~retrieving contest news~~
  - displaying the HTML
* Problems
  - retrieving & displaying problem list
  - retrieving & displaying problem content
    + PDF (chosing the program; xdg-open)
    + HTML (~~S~~pain)
* Results
* Submitting
* User profile
* Rankings
* Cache data for use across calls
  - cache `satori_token`
* Make password prompt hide the input **- needs research**
