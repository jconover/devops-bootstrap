# DevOps Bootstrap

Spin up a complete DevOps workstation on **Windows**, **macOS**, **Ubuntu 25.04**, or **Fedora 42** — with optional **version pinning**, **minimal installs**, **shell completions**, **VS Code tuning**, and turnkey **Dockerfiles** for CI images.

## What’s included

- CLIs: `kubectl`, `eksctl`, `terraform`, `helm`, `flux`* (optional), `aws`, `az`, `gcloud` (+ GKE auth plugin)
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

> **Flux CLI (optional):** Flux install is **off by default** because some environments hit timeouts. Enable it with flags below.

---

## Windows

> Run **PowerShell as Administrator**.

Install latest of everything, VS Code, Podman, Rancher Desktop, completions, SSH & SSO **without Flux**:
```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\scripts\setup-devops-tools.ps1 `
  -IncludeVSCode -IncludePodman -IncludeRancherDesktop -InstallCompletions `
  -ConfigureSsh -ConfigureGh -ConfigureGlab
```

**Enable Flux**:
```powershell
.\scripts\setup-devops-tools.ps1 -IncludeFlux
```

**Pin specific CLI versions** (kubectl/helm/terraform/flux/eksctl):
```powershell
.\scripts\setup-devops-tools.ps1 -PinVersions `
  -KubectlVersion v1.30.4 `
  -HelmVersion v3.15.3 `
  -TerraformVersion 1.9.5 `
  -FluxVersion v2.3.0 `
  -EksctlVersion v0.181.0 `
  -IncludeVSCode -InstallCompletions -IncludeFlux
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
- `-IncludeDockerDesktop`, `-IncludeK9s`, `-IncludeCursor`, `-IncludeClaude`, `-IncludePodman`, `-IncludeRancherDesktop`, `-IncludeFlux`
- `-GitUserName "Your Name" -GitUserEmail "you@example.com"`
- `-ConfigureSsh -ConfigureGh -ConfigureGlab`
- `-InstallCompletions`

---

## macOS / Ubuntu 25.04 / Fedora 42

> macOS uses Homebrew (+ Colima for Docker). Linux uses apt/dnf with official repos & fallbacks.

Latest everything + Docker + Podman + Rancher Desktop + VS Code + completions + SSH + SSO (**no Flux** by default):
```bash
chmod +x scripts/setup-devops-tools-unix.sh
./scripts/setup-devops-tools-unix.sh \
  --docker --podman --rancher --vscode --completions --ssh --gh --glab
```

**Enable Flux**:
```bash
./scripts/setup-devops-tools-unix.sh --flux
```

**Pin versions** (kubectl/helm/terraform/flux/eksctl):
```bash
./scripts/setup-devops-tools-unix.sh --pin \
  --kubectl v1.30.4 --helm v3.15.3 --terraform 1.9.5 --flux v2.3.0 --eksctl v0.181.0 \
  --vscode --completions --flux
```

**Minimal** footprint:
```bash
./scripts/setup-devops-tools-unix.sh --minimal --completions
```

Common optional flags:
- `--docker` (Colima on macOS; Docker CE on Linux)
- `--podman`, `--rancher`, `--k9s`, `--vscode`, `--cursor` (macOS), `--claude` (macOS)
- `--ssh`, `--gh`, `--glab`, `--completions`, `--flux`
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

## CI: GitHub Actions (publishing images)

This repo ships with a workflow at `.github/workflows/publish-images.yml` that:

- Builds both Dockerfiles (`fedora42`, `ubuntu24.04`) for `linux/amd64, linux/arm64`
- Publishes to **GHCR** using the repo’s `GITHUB_TOKEN`
- Optionally publishes to **Docker Hub** if you set secrets
- **Tests Flux on/off** in CI, but **only publishes** the **non-Flux** images

### Configure

1) **GHCR** (no extra secrets required)
   - Images are published to:  
     `ghcr.io/<OWNER>/devops-tools:<tag>-fedora42` and `:<tag>-ubuntu24.04`
   - First push may create a private package; change visibility at your **user/org Packages** page.

2) **Docker Hub** (optional)
   - Add repo secrets:
     - `DOCKERHUB_USERNAME`
     - `DOCKERHUB_TOKEN` (Personal Access Token)
   - Images will also be published to:  
     `<DOCKERHUB_USERNAME>/devops-tools:<tag>-fedora42` and `:<tag>-ubuntu24.04`

### Triggers
- `push` to `main`/`master`
- `push` tags like `v1.2.3` (semantic tags get additional versioned tags)
- pull requests (build only, no push)

### Example pulls
```bash
# GHCR
docker pull ghcr.io/jconover/devops-tools:main-fedora42
docker pull ghcr.io/jconover/devops-tools:v1.0.0-ubuntu24.04
```

> **CI note:** The workflow tests the installers with **Flux both enabled and disabled**, but only **publishes images** for the **non‑Flux** variant. This keeps tags clean while ensuring PRs validate both paths.

---

## Makefile shortcuts

```bash
make help
make unix             # macOS/Linux: VS Code + completions
make unix-with-flux   # macOS/Linux: enable Flux
make unix-minimal     # macOS/Linux: minimal stack + completions
make windows-help     # shows Windows usage (with Flux hint)
make windows-with-flux
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
