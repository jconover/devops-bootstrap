# DevOps Bootstrap

Spin up a complete DevOps workstation on **Windows**, **macOS**, **Ubuntu 25.04**, or **Fedora 42** — with optional **version pinning**, **minimal installs**, **shell completions**, **VS Code tuning**, and turnkey **Dockerfiles** for CI images.

## What’s included

- CLIs: `kubectl`, `eksctl`, `terraform`, `helm`, `flux`, `aws`, `az`, `gcloud` (+ GKE auth plugin)
- Dev: `git`, `gh` (GitHub CLI), `glab` (GitLab CLI), `python3`
- Containers (opt-in):
  - **Docker** (macOS via Colima, Linux via Docker CE, Windows via Docker Desktop)
  - **Podman** (engine/CLI)
  - **Rancher Desktop** (K8s desktop, nerdctl)
- Quality of life:
  - Git identity & sane defaults, global `~/.gitignore_global`
  - Optional SSH keys + `gh`/`glab` single-sign-on
  - Shell completions (PowerShell/Bash/Zsh; Fish on *nix if present)
  - VS Code settings + recommended extensions

---

## Windows

> Run **PowerShell as Administrator**.

Install latest of everything, VS Code, Podman, Rancher Desktop, completions, SSH & SSO:
```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\setup-devops-tools.ps1 `
  -IncludeVSCode -IncludePodman -IncludeRancherDesktop -InstallCompletions `
  -ConfigureSsh -ConfigureGh -ConfigureGlab
```

**Pin specific CLI versions** (kubectl/helm/terraform/flux/eksctl):
```powershell
.\scripts\setup-devops-tools.ps1 -PinVersions `
  -KubectlVersion v1.30.4 `
  -HelmVersion v3.15.3 `
  -TerraformVersion 1.9.5 `
  -FluxVersion v2.3.0 `
  -EksctlVersion v0.181.0 `
  -IncludeVSCode -InstallCompletions
```

**Minimal** footprint (skips az/gcloud/aws and optional apps unless explicitly requested):
```powershell
.\scripts\setup-devops-tools.ps1 -Minimal -InstallCompletions
```

Upgrade or uninstall:
```powershell
.\scripts\setup-devops-tools.ps1 -Upgrade
.\scripts\setup-devops-tools.ps1 -Uninstall
```

Common optional flags:
- `-IncludeDockerDesktop`, `-IncludeK9s`, `-IncludeCursor`, `-IncludeClaude`, `-IncludePodman`, `-IncludeRancherDesktop`
- `-GitUserName "Your Name" -GitUserEmail "you@example.com"`
- `-ConfigureSsh -ConfigureGh -ConfigureGlab`
- `-InstallCompletions`

---

## macOS / Ubuntu 25.04 / Fedora 42

> macOS uses Homebrew (+ Colima for Docker). Linux uses apt/dnf with official repos & fallbacks.

Latest everything + Docker + Podman + Rancher Desktop + VS Code + completions + SSH + SSO:
```bash
chmod +x scripts/setup-devops-tools-unix.sh
./scripts/setup-devops-tools-unix.sh \
  --docker --podman --rancher --vscode --completions --ssh --gh --glab
```

**Pin versions** (kubectl/helm/terraform/flux/eksctl):
```bash
./scripts/setup-devops-tools-unix.sh --pin \
  --kubectl v1.30.4 --helm v3.15.3 --terraform 1.9.5 --flux v2.3.0 --eksctl v0.181.0 \
  --vscode --completions
```

**Minimal** footprint:
```bash
./scripts/setup-devops-tools-unix.sh --minimal --completions
```

Common optional flags:
- `--docker` (Colima on macOS; Docker CE on Linux)
- `--podman`, `--rancher`, `--k9s`, `--vscode`, `--cursor` (macOS), `--claude` (macOS)
- `--ssh`, `--gh`, `--glab`, `--completions`
- `--pin --kubectl vX --helm vY --terraform Z --flux vA --eksctl vB`

---

## Docker images

Build ready-to-use CI images with the toolchain baked in.

Fedora 42:
```bash
docker build -f docker/Dockerfile.fedora42 -t yourname/devops-tools:fedora42 .
```

Ubuntu 24.04:
```bash
docker build -f docker/Dockerfile.ubuntu24.04 -t yourname/devops-tools:ubuntu24.04 .
```

---

## Makefile shortcuts

```bash
make help
make unix             # macOS/Linux: VS Code + completions
make unix-desktop     # macOS/Linux: Docker (Colima/Docker CE) + Podman + Rancher + VS Code + completions
make unix-minimal     # macOS/Linux: minimal stack + completions
make windows-help     # shows Windows examples (including Podman/Rancher)
make docker-fedora
make docker-ubuntu
```

---

### Notes

- **Windows Podman** uses WSL2 under the hood via the official WinGet package.
- **Rancher Desktop**:
  - macOS: Homebrew cask `rancher`.
  - Linux: installed from upstream `.deb`/`.rpm` via the latest GitHub release asset.
  - Windows: WinGet package `SUSE.RancherDesktop`.
- If a CLI isn’t on your PATH immediately after install, open a **new shell**.
- Scripts are safe to re-run; they’ll skip already-installed items and can **upgrade** or **uninstall**.

Licensed MIT — PRs welcome!
