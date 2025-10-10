#!/usr/bin/env bash
set -euo pipefail

# Flags
PIN=false
MINIMAL=false
WITH_DOCKER=false
WITH_VSCODE=false
WITH_K9S=false
WITH_CURSOR=false
WITH_CLAUDE=false
WITH_PODMAN=false
WITH_RANCHER=false
WITH_FLUX=false       # NEW: off by default
DO_GH=false
DO_GLAB=false
DO_SSH=false
DO_COMPLETIONS=false

KUBECTL_VER=""; HELM_VER=""; TERRAFORM_VER=""; FLUX_VER=""; EKSCTL_VER=""
usage(){ cat <<EOF
Usage: $0 [options]
  --pin                         Enable version pinning mode
  --kubectl vX.Y.Z              Pin kubectl
  --helm vX.Y.Z                 Pin helm
  --terraform X.Y.Z             Pin terraform
  --flux vX.Y.Z                 Pin flux (also turns on --flux)
  --eksctl vX.Y.Z               Pin eksctl
  --minimal                     Minimal footprint (skip az/gcloud/aws and extras)
  --docker                      Install Docker engine (Colima on macOS, Docker CE on Linux)
  --podman                      Install Podman engine/CLI
  --rancher                     Install Rancher Desktop
  --vscode                      Install Visual Studio Code + extensions + tuning
  --k9s                         Install k9s
  --cursor                      Install Cursor (macOS only)
  --claude                      Install Claude (macOS only)
  --gh                          Run gh auth login --web
  --glab                        Run glab auth login --hostname gitlab.com -w
  --ssh                         Generate ed25519 key, add to agent, write ~/.ssh/config
  --completions                 Add shell completions (bash/zsh; fish if found)
  --flux                        Install Flux CLI (disabled by default)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pin) PIN=true; shift;;
    --kubectl) KUBECTL_VER="$2"; shift 2;;
    --helm) HELM_VER="$2"; shift 2;;
    --terraform) TERRAFORM_VER="$2"; shift 2;;
    --flux)
      if [[ $# -gt 1 && "$2" =~ ^v?[0-9] ]]; then FLUX_VER="$2"; shift 2; else WITH_FLUX=true; shift; fi
      ;;
    --eksctl) EKSCTL_VER="$2"; shift 2;;
    --minimal) MINIMAL=true; shift;;
    --docker) WITH_DOCKER=true; shift;;
    --podman) WITH_PODMAN=true; shift;;
    --rancher) WITH_RANCHER=true; shift;;
    --vscode) WITH_VSCODE=true; shift;;
    --k9s) WITH_K9S=true; shift;;
    --cursor) WITH_CURSOR=true; shift;;
    --claude) WITH_CLAUDE=true; shift;;
    --gh) DO_GH=true; shift;;
    --glab) DO_GLAB=true; shift;;
    --ssh) DO_SSH=true; shift;;
    --completions) DO_COMPLETIONS=true; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

log(){ printf "\n\033[1;36m[INFO]\033[0m %s\n" "$*"; }
ok(){ printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err(){ printf "\033[1;31m[ERR ]\033[0m %s\n" "$*"; }

OS="$(uname -s)"; ARCH="$(uname -m)"
case "$ARCH" in x86_64) A=amd64;; arm64|aarch64) A=arm64;; *) err "Unsupported arch: $ARCH"; exit 1;; esac
need(){ command -v "$1" >/dev/null 2>&1; }

# ---- macOS setup ----
mac_brew(){
  if ! need brew; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
}
mac_setup(){
  mac_brew
  if $WITH_DOCKER; then
    brew install colima docker || true
    if ! colima status 2>/dev/null | grep -qi running; then
      log "Starting Colima"
      colima start --cpu 4 --memory 6 --disk 40 --network-address || colima start
    fi
    export DOCKER_HOST="unix://${HOME}/.colima/default/docker.sock"
  fi
  brew install git gh glab python jq wget curl unzip openssl || true

  # pinnable clis
  if $PIN && [[ -n "$KUBECTL_VER" ]]; then
    sudo curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VER}/bin/darwin/${A}/kubectl" && sudo chmod +x /usr/local/bin/kubectl
  else brew install kubectl || true; fi

  if $PIN && [[ -n "$HELM_VER" ]]; then
    curl -fsSL "https://get.helm.sh/helm-${HELM_VER}-darwin-${A}.tar.gz" | tar xz -C /tmp && sudo mv /tmp/darwin-${A}/helm /usr/local/bin/helm
  else brew install helm || true; fi

  if $PIN && [[ -n "$TERRAFORM_VER" ]]; then
    curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VER}/terraform_${TERRAFORM_VER}_darwin_${A}.zip" -o /tmp/terraform.zip && sudo unzip -o /tmp/terraform.zip -d /usr/local/bin && sudo chmod +x /usr/local/bin/terraform
  else brew install terraform || true; fi

  if $PIN && [[ -n "$FLUX_VER" ]]; then
    WITH_FLUX=true
    curl -fsSL "https://github.com/fluxcd/flux2/releases/download/${FLUX_VER}/flux_${FLUX_VER}_darwin_${A}.tar.gz" | sudo tar xz -C /usr/local/bin flux
  elif $WITH_FLUX; then
    brew install fluxcd/tap/flux || true
  fi

  if $PIN && [[ -n "$EKSCTL_VER" ]]; then
    curl -fsSL "https://github.com/eksctl-io/eksctl/releases/download/${EKSCTL_VER}/eksctl_Darwin_${A}.tar.gz" | sudo tar xz -C /usr/local/bin eksctl
  else brew install eksctl || true; fi

  if ! $MINIMAL; then
    brew install azure-cli awscli || true
    brew install --cask google-cloud-sdk || true
    gcloud components install gke-gcloud-auth-plugin -q || true
  fi

  $WITH_K9S && brew install k9s || true
  $WITH_VSCODE && brew install --cask visual-studio-code || true
  $WITH_CURSOR && brew install --cask cursor || true
  $WITH_CLAUDE && brew install --cask anthropic-claude || true

  # Podman + Rancher Desktop
  $WITH_PODMAN && brew install podman || true
  $WITH_RANCHER && brew install --cask rancher || true
}

# ---- Ubuntu 25.04 ----
ubuntu_setup(){
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl wget unzip jq git gh glab python3 python3-pip gnupg lsb-release software-properties-common
  if $WITH_DOCKER; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release; echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -y && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
  # kubectl repo - only add if not already present
  if [[ ! -f /etc/apt/sources.list.d/kubernetes.list && ! -f /etc/apt/sources.list.d/kubernetes.sources ]]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor | sudo tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
  fi
  # hashicorp - only add if not already present
  if [[ ! -f /etc/apt/sources.list.d/hashicorp.list && ! -f /etc/apt/sources.list.d/hashicorp.sources ]]; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /etc/apt/keyrings/hashicorp.gpg >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  fi
  sudo apt-get update -y

  sudo apt-get install -y kubectl terraform

  # helm - install from official script since it's not in Ubuntu repos
  if $PIN && [[ -n "$HELM_VER" ]]; then
    curl -fsSL "https://get.helm.sh/helm-${HELM_VER}-linux-${A}.tar.gz" | sudo tar xz -C /usr/local/bin --strip-components=1 linux-${A}/helm
  else
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi

  # Pins override for kubectl and terraform
  if $PIN; then
    [[ -n "$KUBECTL_VER" ]]  && sudo curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/${A}/kubectl" && sudo chmod +x /usr/local/bin/kubectl
    [[ -n "$TERRAFORM_VER" ]]&& curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VER}/terraform_${TERRAFORM_VER}_linux_${A}.zip" -o /tmp/tf.zip && sudo unzip -o /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip
  fi
  # flux
  if [[ -n "$FLUX_VER" ]]; then
    WITH_FLUX=true
    curl -fsSL "https://github.com/fluxcd/flux2/releases/download/${FLUX_VER}/flux_${FLUX_VER}_linux_${A}.tar.gz" | sudo tar xz -C /usr/local/bin flux
  elif $WITH_FLUX; then
    curl -s https://fluxcd.io/install.sh | sudo bash
  fi

  # eksctl
  if [[ -n "$EKSCTL_VER" ]]; then
    curl -fsSL "https://github.com/eksctl-io/eksctl/releases/download/${EKSCTL_VER}/eksctl_Linux_${A}.tar.gz" | sudo tar xz -C /usr/local/bin eksctl
  else
    curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${A}.tar.gz" | sudo tar xz -C /usr/local/bin eksctl
  fi

  if ! $MINIMAL; then
    log "Installing cloud CLI tools (Azure, GCP, AWS)"
    # Azure CLI - only add repo if not already present
    if [[ ! -f /etc/apt/sources.list.d/azure-cli.list && ! -f /etc/apt/sources.list.d/azure-cli.sources ]]; then
      curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ jammy main" | sudo tee /etc/apt/sources.list.d/azure-cli.list >/dev/null
    fi
    # Google Cloud SDK - only add repo if not already present
    if [[ ! -f /etc/apt/sources.list.d/google-cloud-sdk.list && ! -f /etc/apt/sources.list.d/google-cloud-sdk.sources ]]; then
      curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/cloud.google.gpg >/dev/null
      echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
    fi
    sudo apt-get update -y && sudo apt-get install -y azure-cli google-cloud-sdk google-cloud-cli-gke-gcloud-auth-plugin awscli
  else
    log "Skipping cloud CLI tools (minimal installation)"
  fi

  $WITH_K9S && sudo apt-get install -y k9s || true

  # Podman + Rancher Desktop
  if $WITH_PODMAN; then
    sudo apt-get update -y && sudo apt-get install -y podman
  fi
  if $WITH_RANCHER; then
    tmp="$(mktemp -d)"
    url="$(curl -fsSL https://api.github.com/repos/rancher-sandbox/rancher-desktop/releases/latest \
          | jq -r '.assets[] | select(.name|endswith(".deb")) | .browser_download_url' | head -n1)"
    if [[ -n "$url" ]]; then
      curl -fsSL "$url" -o "$tmp/rd.deb"
      sudo apt-get install -y gdebi-core || true
      sudo gdebi -n "$tmp/rd.deb" || sudo dpkg -i "$tmp/rd.deb" && sudo apt-get -f install -y
    else
      echo "Could not determine latest Rancher Desktop .deb URL."
    fi
    rm -rf "$tmp"
  fi

  if $WITH_VSCODE; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/ms_vscode.gpg >/dev/null
    echo "deb [signed-by=/etc/apt/keyrings/ms_vscode.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update -y && sudo apt-get install -y code
  fi
}

# ---- Fedora 42 ----
fedora_setup(){
  sudo dnf -y install ca-certificates curl wget unzip tar jq git gh glab python3 python3-pip
  if $WITH_DOCKER; then
    sudo tee /etc/yum.repos.d/docker-ce.repo >/dev/null <<'EOF'
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://download.docker.com/linux/fedora/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
EOF
    sudo dnf -y clean all && sudo dnf -y makecache
    sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
  fi

  # HashiCorp + Azure repos
  sudo tee /etc/yum.repos.d/hashicorp.repo >/dev/null <<'EOF'
[hashicorp]
name=HashiCorp Stable - Fedora $releasever - $basearch
baseurl=https://rpm.releases.hashicorp.com/fedora/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://rpm.releases.hashicorp.com/gpg
EOF
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo tee /etc/yum.repos.d/azure-cli.repo >/dev/null <<'EOF'
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
  sudo dnf -y makecache

  # kubectl
  if $PIN && [[ -n "$KUBECTL_VER" ]]; then
    curl -fsSLo kubectl "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/${A}/kubectl" && chmod +x kubectl && sudo mv kubectl /usr/local/bin/
  else
    KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
    curl -fsSLo kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/${A}/kubectl" && chmod +x kubectl && sudo mv kubectl /usr/local/bin/
  fi

  # helm
  if $PIN && [[ -n "$HELM_VER" ]]; then
    curl -fsSL "https://get.helm.sh/helm-${HELM_VER}-linux-${A}.tar.gz" | sudo tar xz -C /usr/local/bin --strip-components=1 linux-${A}/helm
  else
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  fi

  # terraform
  if $PIN && [[ -n "$TERRAFORM_VER" ]]; then
    curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VER}/terraform_${TERRAFORM_VER}_linux_${A}.zip" -o /tmp/tf.zip && sudo unzip -o /tmp/tf.zip -d /usr/local/bin && rm /tmp/tf.zip
  else
    sudo dnf -y install terraform || true
  fi

  # eksctl
  if [[ -n "$EKSCTL_VER" ]]; then
    curl -fsSL "https://github.com/eksctl-io/eksctl/releases/download/${EKSCTL_VER}/eksctl_Linux_${A}.tar.gz" | sudo tar xz -C /usr/local/bin eksctl
  else
    curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${A}.tar.gz" | sudo tar xz -C /usr/local/bin eksctl
  fi

  # flux
  if [[ -n "$FLUX_VER" ]]; then
    WITH_FLUX=true
    curl -fsSL "https://github.com/fluxcd/flux2/releases/download/${FLUX_VER}/flux_${FLUX_VER}_linux_${A}.tar.gz" | sudo tar xz -C /usr/local/bin flux
  elif $WITH_FLUX; then
    curl -s https://fluxcd.io/install.sh | sudo bash
  fi

  if ! $MINIMAL; then
    sudo dnf -y install azure-cli || true
    # gcloud tarball (cross-distro) + GKE plugin
    if [[ "$A" == "amd64" ]]; then GURL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz"; else GURL="https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-arm64.tar.gz"; fi
    sudo mkdir -p /opt && curl -fsSL "$GURL" -o /tmp/gcloud.tgz && sudo tar -xzf /tmp/gcloud.tgz -C /opt && rm /tmp/gcloud.tgz && sudo /opt/google-cloud-sdk/install.sh --quiet --path-update=false --bash-completion=false --additional-components gke-gcloud-auth-plugin
    # awscli
    if [[ "$A" == "amd64" ]]; then AWSURL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"; else AWSURL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"; fi
    tmp="$(mktemp -d)"; curl -fsSL "$AWSURL" -o "$tmp/awscliv2.zip"; unzip -q "$tmp/awscliv2.zip" -d "$tmp"; sudo "$tmp/aws/install"; rm -rf "$tmp"
  fi

  $WITH_K9S && sudo dnf -y install k9s || true

  # Podman + Rancher Desktop
  if $WITH_PODMAN; then
    sudo dnf -y install podman
  fi
  if $WITH_RANCHER; then
    tmp="$(mktemp -d)"
    url="$(curl -fsSL https://api.github.com/repos/rancher-sandbox/rancher-desktop/releases/latest \
          | jq -r '.assets[] | select(.name|endswith(".rpm")) | .browser_download_url' | head -n1)"
    if [[ -n "$url" ]]; then
      curl -fsSL "$url" -o "$tmp/rd.rpm"
      sudo rpm -Uvh --replacepkgs "$tmp/rd.rpm" || sudo dnf -y install "$tmp/rd.rpm"
    else
      echo "Could not determine latest Rancher Desktop .rpm URL."
    fi
    rm -rf "$tmp"
  fi

  if $WITH_VSCODE; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    sudo dnf -y install code
  fi
}

# ---- Git config, gitignore, SSH, VS Code tuning, SSO, Completions ----
git_setup(){
  if ! need git; then warn "git not installed?"; return; fi
  read -r -p "Git user.name: " NAME || true
  read -r -p "Git user.email: " EMAIL || true
  [[ -n "${NAME:-}"  ]] && git config --global user.name "$NAME"
  [[ -n "${EMAIL:-}" ]] && git config --global user.email "$EMAIL"
  git config --global init.defaultBranch main
  git config --global pull.rebase false
  git config --global fetch.prune true
  git config --global core.autocrlf input
  if need code; then git config --global core.editor "code --wait"
  elif need cursor; then git config --global core.editor "cursor --wait"; fi
  GI="$HOME/.gitignore_global"
  if [[ ! -f "$GI" ]]; then
cat > "$GI" <<'EOF'
.DS_Store
Thumbs.db
.vscode/
.history/
.idea/
*.code-workspace
node_modules/
npm-debug.log*
yarn*.log
pnpm-debug.log
dist/
build/
__pycache__/
*.py[cod]
*.egg-info/
.venv/
.env
bin/
vendor/
*.tfstate
*.tfstate.*
*.tfplan
.terraform/
.terraform.lock.hcl
crash.log
*.kube/config.lock
*.log
*.tmp
*.swp
EOF
  fi
  git config --global core.excludesfile "$GI"
  ok "Git configured"
}

ssh_setup(){
  $DO_SSH || return 0
  mkdir -p "$HOME/.ssh"
  KEY="$HOME/.ssh/id_ed25519"
  if [[ ! -f "$KEY" ]]; then
    EMAIL="$(git config --global user.email || true)"
    ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY" -N ""
  fi
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add "$KEY" || true
  CFG="$HOME/.ssh/config"
  if [[ ! -f "$CFG" ]]; then
cat > "$CFG" <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile $KEY
  AddKeysToAgent yes
Host gitlab.com
  HostName gitlab.com
  User git
  IdentityFile $KEY
  AddKeysToAgent yes
EOF
  fi
  echo; echo "SSH public key:"; cat "${KEY}.pub"
}

vscode_tune(){
  $WITH_VSCODE || return 0
  need code || { warn "VS Code missing; skipping tuning"; return 0; }
  SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
  [[ "$(uname -s)" == "Linux" ]] && SETTINGS_DIR="$HOME/.config/Code/User"
  mkdir -p "$SETTINGS_DIR"
  SETTINGS="$SETTINGS_DIR/settings.json"
  [[ -f "$SETTINGS" ]] && cp "$SETTINGS" "$SETTINGS.bak"
  cat > "$SETTINGS" <<'EOF'
{
  "git.enableSmartCommit": true,
  "git.confirmSync": false,
  "git.autofetch": true,
  "git.rebaseWhenSync": false,
  "gitlens.advanced.messages": { "suppressShowKeyBindingsNotice": true },
  "editor.formatOnSave": true,
  "files.trimTrailingWhitespace": true,
  "telemetry.telemetryLevel": "off"
}
EOF
  for ext in eamodio.gitlens ms-azuretools.vscode-docker ms-kubernetes-tools.vscode-kubernetes-tools hashicorp.terraform redhat.vscode-yaml ms-python.python; do
    code --install-extension "$ext" --force >/dev/null 2>&1 || true
  done
  ok "VS Code tuned"
}

sso(){
  $DO_GH && need gh && gh auth login --web || true
  $DO_GLAB && need glab && glab auth login --hostname gitlab.com -w || true
}

completions(){
  $DO_COMPLETIONS || return 0
  # bash
  if [[ -n "${BASH_VERSION:-}" ]]; then
    RC="$HOME/.bashrc"
    {
      echo '# DevOps completions'
      echo 'command -v kubectl >/dev/null && source <(kubectl completion bash)'
      echo 'command -v helm >/dev/null && source <(helm completion bash)'
      echo 'command -v flux >/dev/null && source <(flux completion bash)'
      echo 'command -v eksctl >/dev/null && source <(eksctl completion bash)'
      echo 'command -v gh >/dev/null && source <(gh completion -s bash)'
      echo 'command -v glab >/dev/null && source <(glab completion -s bash)'
      echo 'command -v terraform >/dev/null && complete -C terraform terraform'
      echo 'command -v podman >/dev/null && source <(podman completion bash)'
    } >> "$RC"
    ok "Bash completions added (restart shell)"
  fi
  # zsh
  if [[ -n "${ZSH_VERSION:-}" || -f "$HOME/.zshrc" ]]; then
    RC="$HOME/.zshrc"
    {
      echo '# DevOps completions'
      echo 'command -v kubectl >/dev/null && source <(kubectl completion zsh)'
      echo 'command -v helm >/dev/null && source <(helm completion zsh)'
      echo 'command -v flux >/dev/null && source <(flux completion zsh)'
      echo 'command -v eksctl >/dev/null && source <(eksctl completion zsh)'
      echo 'command -v gh >/dev/null && gh completion -s zsh > ~/.zfunc/_gh 2>/dev/null || true'
      echo 'command -v glab >/dev/null && glab completion -s zsh > ~/.zfunc/_glab 2>/dev/null || true'
      echo 'command -v podman >/dev/null && source <(podman completion zsh)'
      echo 'fpath+=~/.zfunc'
      echo 'autoload -U compinit && compinit'
    } >> "$RC"
    mkdir -p ~/.zfunc || true
    ok "Zsh completions added (restart shell)"
  fi
  # fish
  if command -v fish >/dev/null 2>&1; then
    mkdir -p ~/.config/fish/completions
    command -v kubectl >/dev/null && kubectl completion fish > ~/.config/fish/completions/kubectl.fish || true
    command -v helm >/dev/null && helm completion fish > ~/.config/fish/completions/helm.fish || true
    command -v flux >/dev/null && flux completion fish > ~/.config/fish/completions/flux.fish || true
    command -v eksctl >/dev/null && eksctl completion fish > ~/.config/fish/completions/eksctl.fish || true
    command -v gh >/dev/null && gh completion -s fish > ~/.config/fish/completions/gh.fish || true
    command -v glab >/dev/null && glab completion -s fish > ~/.config/fish/completions/glab.fish || true
    command -v podman >/dev/null && podman completion fish > ~/.config/fish/completions/podman.fish || true
    ok "Fish completions installed"
  fi
}

# Dispatch by OS
case "$OS" in
  Darwin) mac_setup ;;
  Linux)
    source /etc/os-release
    if [[ "$ID" == "ubuntu" && "$VERSION_ID" == "25.04" ]]; then ubuntu_setup
    elif [[ -f /etc/fedora-release ]] && grep -q "release 42" /etc/fedora-release; then fedora_setup
    else err "Supported: macOS, Ubuntu 25.04, Fedora 42"; exit 1; fi
    ;;
  *) err "Unsupported OS $OS"; exit 1;;
esac

git_setup
ssh_setup
vscode_tune
sso
completions

ok "Unix setup complete ✅"
