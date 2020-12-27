**WARNING: Only Unix-like systems are supported at the moment**
# SatoriCLI
A user-friendliness-first CLI client for the [Satori testing system](https://satori.tcs.uj.edu.pl).
It works by web scraping, since there is no API there and the Satori project is
[*"an abandoned project and is not safe for use"*](https://bitbucket.org/satoriproject/satori),
as put by its creators and (ex-?)maintainers.

It is still in use though, so that's why SatoriCLI exists in the first place.

# Installation and Running
This is a work in progress... Packaging up Julia apps into a portable way is tough, and
[PackageCompiler.jl](https://github.com/JuliaLang/PackageCompiler.jl) helps with that,
but I have to figure that out too.

Right now you can run it (if you have Julia installed) by, from the repo root, running
`julia -e 'include("src/SatoriCLI.jl"); SatoriCLI.julia_main()' -- <program arguments>`.
This is very crude since that recompiles the whole package every time, but it's how I'm testing it at the moment.
Generating a sysimage could help and be a good idea when testing, but it's far from being perfect.

Also, first you should launch the Julia REPL in the repo root and
```
] activate .
] resolve
] instantiate
```

# Usage
**`satori-cli [options] <command> [cmdargs]`**  
Options:
* `-color`/`-nocolor` - enable/disable colored output (default is `-color` if the output is a TTY)
* `-cache`/`-nocache` - enable/disable caching of data (does nothing yet, since caching isn't implemented yet)
* `-remember`/`-noremeber` - enable/disable *saving* the login credentials

# Features
The following features are fully implemented:
* Login and saving login credentials
* Retrieving and displaying contest list
The following are at least work-in-progress:
* Retrieving contest news
* Retrieving problem contents
* Retrieving submits/results
And the following are planned:
* Caching **- much wanted asap**
* Submitting to problems
* User profile
* Retrieving and displaying rankings
* Applying to contests
See [`todo.md`](/todo.md) for details.

# Contributing
Contributions such as implementing new features, or finding ways to retrieve data faster are welcome.
You can open an issues concerning the latter one. The code style is pretty much already visible.
