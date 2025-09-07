SHELL := /bin/bash

.PHONY: help unix unix-desktop unix-minimal windows-help docker-fedora docker-ubuntu

help:
	@echo "Targets:"
	@echo "  make unix          - macOS/Ubuntu25.04/Fedora42 with VSCode + completions"
	@echo "  make unix-desktop  - macOS/Ubuntu25.04/Fedora42 with Docker+Podman+Rancher+VSCode+completions"
	@echo "  make unix-minimal  - macOS/Ubuntu25.04/Fedora42 minimal stack + completions"
	@echo "  make windows-help  - Show Windows usage examples"
	@echo "  make docker-fedora - Build Fedora 42 devops-tools image"
	@echo "  make docker-ubuntu - Build Ubuntu 24.04 devops-tools image"

unix:
	chmod +x scripts/setup-devops-tools-unix.sh
	./scripts/setup-devops-tools-unix.sh --vscode --completions

unix-desktop:
	chmod +x scripts/setup-devops-tools-unix.sh
	./scripts/setup-devops-tools-unix.sh --docker --podman --rancher --vscode --completions

unix-minimal:
	chmod +x scripts/setup-devops-tools-unix.sh
	./scripts/setup-devops-tools-unix.sh --minimal --completions

windows-help:
	@echo "Run PowerShell as Administrator, then for a full desktop:"
	@echo "  Set-ExecutionPolicy -Scope Process Bypass -Force"
	@echo "  .\\scripts\\setup-devops-tools.ps1 -IncludeVSCode -IncludePodman -IncludeRancherDesktop -InstallCompletions -ConfigureSsh -ConfigureGh -ConfigureGlab"
	@echo ""
	@echo "Pin versions example:"
	@echo "  .\\scripts\\setup-devops-tools.ps1 -PinVersions -KubectlVersion v1.30.4 -HelmVersion v3.15.3 -TerraformVersion 1.9.5 -FluxVersion v2.3.0 -EksctlVersion v0.181.0 -IncludeVSCode -InstallCompletions"

docker-fedora:
	docker build -f docker/Dockerfile.fedora42 -t devops-tools:fedora42 .

docker-ubuntu:
	docker build -f docker/Dockerfile.ubuntu24.04 -t devops-tools:ubuntu24.04 .
