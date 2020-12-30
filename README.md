**WARNING: Only Unix-like systems are supported at the moment**

![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/MasFlam/SatoriCLI.jl?sort=semver)

# SatoriCLI
A user-friendliness-first CLI client for the [Satori testing system](https://satori.tcs.uj.edu.pl).
It works by web scraping, since there is no Satori API and the Satori project is
[*"an abandoned project and is not safe for use"*](https://bitbucket.org/satoriproject/satori),
as put by its creators and (ex-?)maintainers.

It is still in use though, so that's why SatoriCLI exists in the first place.

# Installation
Download the latest release, unpack it, `cd` into that directory and run `install.sh` (will probably need root):
```
$ tar -xzf SatoriCLI.tar.gz
$ cd SatoriCLI
$ sudo ./install.sh
```

# Usage
**`satori-cli [options] <command> [cmdargs]`**

Options:
* `-color`/`-nocolor` - enable/disable colored output (default is `-color` if the output is a TTY)
* `-cache`/`-nocache` - enable/disable caching of data (default `-cache`)
* `-remember`/`-noremeber` - enable/disable *saving* the login credentials

Commands: (can be shortened to any of their prefixes)
* `help` - Get usage help
* `version` - Get SatoriCLI version
* `login` - Just prompt for the login credentials and see if they work
* `forget` - Forget the saved login credentials
* `contests` - Retrieve contests list
* `news <contest>` - Retrieve contest news
* `problems <contest>` - Retrieve contest problem list
* `submit <contest> : <problem> : <filepath>` - Submit the file under `<filepath>` to a problem
* `profile` - See the user profile

`<contest>` can be either a contest id, or one or more strings that should all case-insensitively be present
in the wanted contest name or description. Same is with `<problem>`.

# Features
The following features are fully implemented:
* Login and saving login credentials
* Retrieving and displaying contest list
* Submitting to problems
* Retrieving and displaying user profile
* Caching

The following are at least work-in-progress:
* Retrieving contest news
* Retrieving problem contents
* Retrieving submits/results

And the following are planned:
* Retrieving and displaying rankings
* Applying to contests

See [`todo.md`](/todo.md) for details.

# Building
Clone the repo and run these in the julia REPL: (by running `julia`)
```
] activate .
] resolve
] instantiate
```
Then to build the full (release) package from source:
* Create a file named `precompile_in.txt` containing:
```
<a couple of keywords for an existing contest>
<id of that contest>
<id of a problem in that contest>
<path to a file that will be submitted as a solution to that problem>
<username>
<password>
```
  This will be used for compilation, see [`precompile_app.jl`](/precompile_app.jl).
* `make build`
* `make install` or `make prefix=/usr/local/bin install` (if you want to)

For testing the program, use `julia --project -e 'include("src/SatoriCLI.jl"); SatoriCLI.julia_main()' -- <program arguments>` - it's way faster than rebuilding the whole package.

# Contributing
Contributions such as implementing new features, or finding ways to retrieve data faster are welcome.
You can open an issue concerning the latter one. The code style is pretty much already visible too.
