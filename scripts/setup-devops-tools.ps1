#Requires -RunAsAdministrator
param(
  # Optional installs
  [switch]$IncludeDockerDesktop,
  [switch]$IncludeK9s,
  [switch]$IncludeVSCode,
  [switch]$IncludeCursor,
  [switch]$IncludeClaude,
  [switch]$IncludeGkeAuth,
  [switch]$IncludePodman,
  [switch]$IncludeRancherDesktop,
  [switch]$IncludeFlux,        # NEW: off by default
  [switch]$IncludeGitLabCli,
  [switch]$IncludeCloudCLIs,   # Installs AWS, Azure, and Google Cloud CLIs

  # Modes
  [switch]$Upgrade,
  [switch]$Uninstall,
  [switch]$Minimal,             # Skip az/gcloud/aws and optional apps unless explicitly requested
  [switch]$InstallCompletions,  # Add completions to PowerShell profile

  # Git identity & auth
  [string]$GitUserName,
  [string]$GitUserEmail,
  [switch]$ConfigureSsh,
  [switch]$ConfigureGh,
  [switch]$ConfigureGlab,

  # Version pinning (when -PinVersions or individual versions are provided)
  [switch]$PinVersions,
  [string]$KubectlVersion,
  [string]$HelmVersion,
  [string]$TerraformVersion,
  [string]$FluxVersion,
  [string]$EksctlVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function Log([string]$m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Ok([string]$m){ Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn([string]$m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Err([string]$m){ Write-Host "[ERR ] $m" -ForegroundColor Red }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Err "WinGet not found. Install 'App Installer' from Microsoft Store."; exit 1 }

# Where pinned binaries live
$BinRoot = "$Env:ProgramFiles\DevOps\bin"; New-Item -ItemType Directory -Force -Path $BinRoot | Out-Null
function Refresh-Path {
  $machine = [System.Environment]::GetEnvironmentVariable("PATH","Machine")
  if ($machine -notlike "*$BinRoot*") { [System.Environment]::SetEnvironmentVariable("PATH", "$machine;$BinRoot", "Machine") }
  $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")
}

function Is-Installed([string]$Id) { try { $null -ne (winget list --id $Id -e 2>$null | Select-String -SimpleMatch $Id) } catch { $false } }
function Install-WinGet([string]$Id, [string]$Display) {
  if (Is-Installed $Id) { Ok "$Display already installed"; return }
  Log "Installing $Display ($Id)"
  try { winget install --id $Id -e --accept-source-agreements --accept-package-agreements --silent }
  catch { winget install --id $Id -e --accept-source-agreements --accept-package-agreements }
  Start-Sleep 2
  if (-not (Is-Installed $Id)) { Err "Failed to install $Display"; exit 1 }
  Ok "$Display installed"
}
function Upgrade-WinGet([string]$Id, [string]$Display) {
  if (-not (Is-Installed $Id)) { Warn "$Display not installed; skipping upgrade"; return }
  Log "Upgrading $Display"; try { winget upgrade --id $Id -e --accept-source-agreements --accept-package-agreements --silent } catch { winget upgrade --id $Id -e --accept-source-agreements --accept-package-agreements }
  Ok "$Display upgraded/at-latest"
}
function Uninstall-WinGet([string]$Id, [string]$Display) {
  if (-not (Is-Installed $Id)) { Ok "$Display not installed"; return }
  Log "Uninstalling $Display"; try { winget uninstall --id $Id -e --silent } catch { winget uninstall --id $Id -e }
  Ok "$Display removed"
}
function Install-ZipBinary([string]$Url, [string]$ExeName, [string]$Display) {
  $tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ([guid]::NewGuid())) -Force
  $zip = Join-Path $tmp "pkg.zip"
  Log "Downloading $Display from $Url"
  Invoke-WebRequest -Uri $Url -OutFile $zip -UseBasicParsing
  Expand-Archive $zip -DestinationPath $tmp -Force
  $exe = Get-ChildItem -Path $tmp -Recurse -Filter $ExeName | Select-Object -First 1
  if (-not $exe) { Err "Could not find $ExeName in archive for $Display"; exit 1 }
  Copy-Item $exe.FullName (Join-Path $BinRoot $ExeName) -Force
  Remove-Item $tmp -Recurse -Force
  Ok "$Display installed to $BinRoot"
}
function Install-File([string]$Url, [string]$TargetName, [string]$Display) {
  $dst = Join-Path $BinRoot $TargetName
  Log "Downloading $Display from $Url"
  Invoke-WebRequest -Uri $Url -OutFile $dst -UseBasicParsing
  Ok "$Display installed to $dst"
}

# Build pinnable list (conditionally include Flux)
$CORE_PINNABLE = @(
  @{ Name="kubectl";  WingetId="Kubernetes.kubectl";  Pin=$PinVersions -or ($KubectlVersion);  Version=$KubectlVersion },
  @{ Name="helm";     WingetId="Helm.Helm";           Pin=$PinVersions -or ($HelmVersion);     Version=$HelmVersion },
  @{ Name="terraform";WingetId="Hashicorp.Terraform"; Pin=$PinVersions -or ($TerraformVersion);Version=$TerraformVersion },
  @{ Name="eksctl";   WingetId="eksctl.eksctl";       Pin=$PinVersions -or ($EksctlVersion);   Version=$EksctlVersion }
)
if ($IncludeFlux -or $FluxVersion -or $PinVersions) {
  $CORE_PINNABLE += @{ Name="flux"; WingetId="fluxcd.flux"; Pin=$PinVersions -or ($FluxVersion); Version=$FluxVersion }
}

# Always via WinGet (unless Minimal removes some)
$PACKAGES_CORE_WINGET = @(
  @{ Id="Git.Git";             Name="Git" },
  @{ Id="GitHub.cli";          Name="GitHub CLI" },
  @{ Id="Python.Python.3.12";  Name="Python 3" }
)
if ($IncludeCloudCLIs) {
  $PACKAGES_CORE_WINGET += @(
    @{ Id="Microsoft.AzureCLI"; Name="Azure CLI" },
    @{ Id="Google.CloudSDK";    Name="Google Cloud SDK" },
    @{ Id="Amazon.AWSCLI";      Name="AWS CLI v2" }
  )
} elseif (-not $Minimal) {
  $PACKAGES_CORE_WINGET += @(
    @{ Id="Microsoft.AzureCLI"; Name="Azure CLI" },
    @{ Id="Google.CloudSDK";    Name="Google Cloud SDK" },
    @{ Id="Amazon.AWSCLI";      Name="AWS CLI v2" }
  )
}

$PACKAGES_OPTIONAL = @()
if ($IncludeDockerDesktop)  { $PACKAGES_OPTIONAL += @{ Id="Docker.DockerDesktop";    Name="Docker Desktop" } }
if ($IncludeK9s)            { $PACKAGES_OPTIONAL += @{ Id="Derailed.k9s";            Name="k9s" } }
if ($IncludeVSCode)         { $PACKAGES_OPTIONAL += @{ Id="Microsoft.VisualStudioCode"; Name="Visual Studio Code" } }
if ($IncludeCursor)         { $PACKAGES_OPTIONAL += @{ Id="Cursor.Cursor";           Name="Cursor IDE" } }
if ($IncludeClaude)         { $PACKAGES_OPTIONAL += @{ Id="Anthropic.Claude";        Name="Claude Desktop" } }
if ($IncludeGitLabCli)      { $PACKAGES_OPTIONAL += @{ Id="GitLab.gitlab-cli";       Name="GitLab CLI" } }
if ($IncludePodman)         { $PACKAGES_OPTIONAL += @{ Id="RedHat.Podman";           Name="Podman" } }
if ($IncludeRancherDesktop) { $PACKAGES_OPTIONAL += @{ Id="SUSE.RancherDesktop";     Name="Rancher Desktop" } }

Refresh-Path

if ($Uninstall) {
  foreach ($p in $PACKAGES_OPTIONAL + $PACKAGES_CORE_WINGET) { Uninstall-WinGet $p.Id $p.Name }
  foreach ($exe in "kubectl.exe","helm.exe","terraform.exe","flux.exe","eksctl.exe") { $path = Join-Path $BinRoot $exe; if (Test-Path $path){ Remove-Item $path -Force } }
  Ok "Uninstall complete."; exit 0
}

if ($Upgrade) {
  foreach ($p in $PACKAGES_CORE_WINGET) { Upgrade-WinGet $p.Id $p.Name }
  foreach ($p in $PACKAGES_OPTIONAL)    { Upgrade-WinGet $p.Id $p.Name }
  Ok "Upgrade complete (re-pin binaries by re-running with -PinVersions)."; exit 0
}

# Install pinnable (or via WinGet fallback)
foreach ($c in $CORE_PINNABLE) {
  if ($c.Pin) {
    switch ($c.Name) {
      "kubectl"  { $v=$c.Version; if (-not $v){$v="v1.30.4"}; Install-File "https://dl.k8s.io/release/$v/bin/windows/amd64/kubectl.exe" "kubectl.exe" "kubectl $v" }
      "helm"     { $v=$c.Version; if (-not $v){$v="v3.15.3"}; Install-ZipBinary "https://get.helm.sh/helm-$v-windows-amd64.zip" "helm.exe" "Helm $v" }
      "terraform"{ $v=$c.Version; if (-not $v){$v="1.9.5"};  Install-ZipBinary "https://releases.hashicorp.com/terraform/$v/terraform_${v}_windows_amd64.zip" "terraform.exe" "Terraform $v" }
      "flux"     { $v=$c.Version; if (-not $v){$v="v2.3.0"}; Install-ZipBinary "https://github.com/fluxcd/flux2/releases/download/$v/flux_${v}_windows_amd64.zip" "flux.exe" "Flux $v" }
      "eksctl"   { $v=$c.Version; if (-not $v){$v="v0.181.0"};Install-ZipBinary "https://github.com/eksctl-io/eksctl/releases/download/$v/eksctl_Windows_amd64.zip" "eksctl.exe" "eksctl $v" }
    }
  } else {
    # If flux is not requested, we won't have a flux entry in $CORE_PINNABLE
    Install-WinGet $c.WingetId $c.Name
  }
}

# Install via WinGet
foreach ($p in $PACKAGES_CORE_WINGET) { Install-WinGet $p.Id $p.Name }
foreach ($p in $PACKAGES_OPTIONAL)    { Install-WinGet $p.Id $p.Name }
Refresh-Path

# Optional GKE plugin
if ($IncludeGkeAuth -and (Get-Command gcloud -ErrorAction SilentlyContinue)) {
  try { gcloud components install gke-gcloud-auth-plugin -q } catch { Warn "gcloud components failed" }
}

# Git config + ignore
function Configure-Git {
  $name  = if ($GitUserName) { $GitUserName } else { Read-Host "Git user.name" }
  $email = if ($GitUserEmail){ $GitUserEmail } else { Read-Host "Git user.email" }
  git config --global user.name  "$name"
  git config --global user.email "$email"
  git config --global init.defaultBranch main
  git config --global core.autocrlf true
  git config --global fetch.prune true
  git config --global pull.rebase false
  git config --global credential.helper manager-core
  if (Get-Command code -ErrorAction SilentlyContinue) { git config --global core.editor "code --wait" }
  elseif (Get-Command cursor -ErrorAction SilentlyContinue) { git config --global core.editor "cursor --wait" }
  Ok "Git configured for $name <$email>"
}
if (Get-Command git -ErrorAction SilentlyContinue) { Configure-Git } else { Warn "Git missing; skipped Git config" }

$gi = Join-Path $HOME ".gitignore_global"
if (-not (Test-Path $gi)) {
@"
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
"@ | Out-File -Encoding ascii -FilePath $gi
}
git config --global core.excludesfile $gi

# SSH + SSO
if ($ConfigureSsh) {
  $svc = Get-Service -Name ssh-agent -ErrorAction SilentlyContinue
  if ($svc) { if ($svc.StartType -ne 'Automatic'){ Set-Service ssh-agent -StartupType Automatic }; if ($svc.Status -ne 'Running'){ Start-Service ssh-agent } }
  $sshDir = Join-Path $HOME ".ssh"; if (-not (Test-Path $sshDir)){ New-Item -ItemType Directory -Path $sshDir | Out-Null }
  $key = Join-Path $sshDir "id_ed25519"
  if (-not (Test-Path $key)) {
    $email = git config --global user.email
    ssh-keygen -t ed25519 -C "$email" -f $key -N ""
  }
  try { ssh-add $key | Out-Null } catch { }
  $cfg = Join-Path $sshDir "config"
  if (-not (Test-Path $cfg)) {
@"
Host github.com
  HostName github.com
  User git
  IdentityFile $key
  AddKeysToAgent yes
Host gitlab.com
  HostName gitlab.com
  User git
  IdentityFile $key
  AddKeysToAgent yes
"@ | Out-File -Encoding ascii -FilePath $cfg
  }
  Write-Host "`nSSH public key:" -ForegroundColor Yellow
  Get-Content ($key + ".pub")
}
if ($ConfigureGh -and (Get-Command gh -ErrorAction SilentlyContinue))   { try { gh auth login --web } catch { } }
if ($ConfigureGlab -and (Get-Command glab -ErrorAction SilentlyContinue)){ try { glab auth login --hostname gitlab.com -w } catch { } }

# PowerShell completions
if ($InstallCompletions) {
  $profilePath = $PROFILE.CurrentUserAllHosts
  $parent = Split-Path $profilePath
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Force -Path $profilePath | Out-Null }
  Add-Content $profilePath @"
# DevOps completions (added by setup-devops-tools.ps1)
if (Get-Command kubectl -ErrorAction SilentlyContinue) { kubectl completion powershell | Out-String | Invoke-Expression }
if (Get-Command helm -ErrorAction SilentlyContinue)    { helm completion powershell    | Out-String | Invoke-Expression }
if (Get-Command flux -ErrorAction SilentlyContinue)    { flux completion powershell    | Out-String | Invoke-Expression }
if (Get-Command terraform -ErrorAction SilentlyContinue){ try { terraform -install-autocomplete | Out-Null } catch {} }
if (Get-Command eksctl -ErrorAction SilentlyContinue)  { eksctl completion powershell  | Out-String | Invoke-Expression }
if (Get-Command gh -ErrorAction SilentlyContinue)      { gh completion -s powershell   | Out-String | Invoke-Expression }
if (Get-Command glab -ErrorAction SilentlyContinue)    { glab completion -s powershell | Out-String | Invoke-Expression }
if (Get-Command podman -ErrorAction SilentlyContinue)  { podman completion powershell  | Out-String | Invoke-Expression }
"@
  Ok "PowerShell completions added. Restart your shell."
}

# Verify (best-effort)
Write-Host ""
foreach ($cmd in @(
  "kubectl.exe version --client","eksctl.exe version","terraform.exe -version | Select-Object -First 1",
  "helm.exe version","az version | Out-String | Select-String 'azure-cli'",
  "gcloud version | Select-Object -First 2","aws --version","flux.exe version",
  "git --version","gh --version","glab --version","python --version",
  "podman --version"
)) { try { Invoke-Expression $cmd } catch { } }

Ok "Windows setup complete ✅"
