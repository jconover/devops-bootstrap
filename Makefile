SHELL := /bin/bash

.PHONY: help unix unix-with-flux unix-minimal windows-help windows-with-flux docker-fedora docker-ubuntu

help:
	@echo "Targets:"
	@echo "  make unix              - macOS/Ubuntu25.04/Fedora42 install (no Flux)"
	@echo "  make unix-with-flux    - macOS/Ubuntu25.04/Fedora42 install (Flux enabled)"
	@echo "  make unix-minimal      - Minimal stack (no cloud CLIs, no extras)"
	@echo "  make windows-help      - Show Windows usage"
	@echo "  make windows-with-flux - Windows example with Flux enabled"
	@echo "  make docker-fedora     - Build Fedora 42 devops-tools image"
	@echo "  make docker-ubuntu     - Build Ubuntu 24.04 devops-tools image"

unix:
	chmod +x scripts/setup-devops-tools-unix.sh
	./scripts/setup-devops-tools-unix.sh --vscode --completions

unix-with-flux:
	chmod +x scripts/setup-devops-tools-unix.sh
	./scripts/setup-devops-tools-unix.sh --vscode --completions --flux

unix-minimal:
	chmod +x scripts/setup-devops-tools-unix.sh
	./scripts/setup-devops-tools-unix.sh --minimal --completions

windows-help:
	@echo "Run PowerShell as Administrator, then:"
	@echo "  Set-ExecutionPolicy -Scope Process Bypass -Force"
	@echo "  .\\scripts\\setup-devops-tools.ps1 -IncludeVSCode -InstallCompletions"
	@echo "  # Add -IncludeFlux to enable Flux"

windows-with-flux:
	@echo "Run PowerShell as Administrator, then:"
	@echo "  Set-ExecutionPolicy -Scope Process Bypass -Force"
	@echo "  .\\scripts\\setup-devops-tools.ps1 -IncludeVSCode -InstallCompletions -IncludeFlux"

docker-fedora:
	docker build -f docker/Dockerfile.fedora42 -t devops-tools:fedora42 .

docker-ubuntu:
	docker build -f docker/Dockerfile.ubuntu24.04 -t devops-tools:ubuntu24.04 .
