ifndef prefix
prefix := /usr/local/bin
endif

.PHONY: help build package install

help:
	@echo 'make build - Build the package'
	@echo 'make package - Tarball the built package'
	@echo 'make [prefix=/usr/local/bin] install - Install to [prefix]'

build:
	./build.jl

package:
	echo '#!/bin/sh' >> build/SatoriCLI/install.sh
	echo cp -r build/SatoriCLI \"$$\{1:-/usr/local/bin\}\" >> build/SatoriCLI/install.sh
	echo ln -s SatoriCLI/bin/SatoriCLI \"$$\{1:-/usr/local/bin\}\"/satori-cli >> build/SatoriCLI/install.sh
	chmod +x build/SatoriCLI/install.sh
	cp LICENSE build/SatoriCLI/LICENSE
	tar -czf build/SatoriCLI.tar.gz build/SatoriCLI

install:
	cp -r build/SatoriCLI $(prefix)
	ln -s SatoriCLI/bin/SatoriCLI $(prefix)/satori-cli
