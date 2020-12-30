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
	echo cp -r . \"$$\{1:-/usr/local/bin\}\"/SatoriCLI >> build/SatoriCLI/install.sh
	echo ln -s SatoriCLI/bin/SatoriCLI \"$$\{1:-/usr/local/bin\}\"/satori-cli >> build/SatoriCLI/install.sh
	chmod +x build/SatoriCLI/install.sh
	cp LICENSE build/SatoriCLI/LICENSE
	cd build && tar -czf SatoriCLI.tar.gz SatoriCLI

install:
	cp -r build/SatoriCLI $(prefix)
	ln -s SatoriCLI/bin/SatoriCLI $(prefix)/satori-cli
