# PHASE GATE: run only after a phase is complete and tested (see docs/ROADMAP.md > Publication Policy).
# Preferred path is pushing from VS Code; this script is an optional helper for the first push + bootstrap.
# Publish OpenNetIQ to GitHub from Windows (first push) and run the bootstrap.
# Prereqs: winget install Git.Git GitHub.cli jqlang.jq ; then: gh auth login
# Usage (PowerShell, from the repo root):  .\scripts\github\publish.ps1 -Owner <github-user-or-org> [-Repo opennetiq] [-Private]
param(
  [Parameter(Mandatory=$true)][string]$Owner,
  [string]$Repo = "opennetiq",
  [switch]$Private
)
$ErrorActionPreference = "Stop"
$full = "$Owner/$Repo"
gh auth status | Out-Null

if (-not (Test-Path .git)) {
  git init -b main
  git add -A
  git commit -m "chore: bootstrap OpenNetIQ repository (Phase 0 foundation)"
}

$visibility = if ($Private) { "--private" } else { "--public" }
gh repo view $full 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  gh repo create $full $visibility --description "Open-source mobile network QoS/QoE measurement, drive-test and coverage mapping platform" --source . --remote origin
} elseif (-not (git remote | Select-String -Quiet origin)) {
  git remote add origin "https://github.com/$full.git"
}
git push -u origin main

(Get-Content .github\CODEOWNERS) -replace '@OWNER', "@$Owner" | Set-Content .github\CODEOWNERS
git add .github\CODEOWNERS
git commit -m "chore: set CODEOWNERS"
git push origin main

# Labels, milestones, 40 backlog issues, develop branch, branch protection
& "C:\Program Files\Git\bin\bash.exe" ./scripts/github/bootstrap.sh $full
git fetch origin
git checkout -B develop origin/develop
Write-Host "Done: https://github.com/$full"
