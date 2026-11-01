# AI Architecture Ledger installer for Windows (PowerShell).
# Runs install.sh using the bash bundled with Git for Windows. Git uses that same
# bash to run hooks, so nothing extra needs to be installed.
#
# Usage:
#   .\install.ps1 [--local | --shared] [path\to\your\project]
#   irm https://raw.githubusercontent.com/MJ0006/AI-Architecture-Ledger/main/install.ps1 | iex
#
# Everything runs inside a script block, so settings don't leak into your session when piped to iex.
& {
    $ErrorActionPreference = "Stop"
    $Mode = @($args | Where-Object { $_ -in @("--local", "--shared") })
    $Target = @($args | Where-Object { $_ -notlike "--*" }) + "." | Select-Object -First 1
    $RepoUrl = "https://github.com/MJ0006/AI-Architecture-Ledger.git"

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git is required. Install it from https://git-scm.com/download/win and re-run."
    }

    # Find Git's bash: <Git>\mingw64\libexec\git-core -> <Git>\bin\bash.exe
    $gitHome = Split-Path (Split-Path (Split-Path (git --exec-path)))
    $bash = "$gitHome\bin\bash.exe"   # not plain "bash": on Windows that may be WSL's, which can't read Windows paths
    if (-not (Test-Path $bash)) { throw "Could not find Git Bash ($bash). Reinstall Git for Windows." }

    $tmp = $null
    try {
        if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot "install.sh"))) {
            $installer = Join-Path $PSScriptRoot "install.sh"
        } else {
            $tmp = Join-Path ([IO.Path]::GetTempPath()) ("ai-ledger-" + [guid]::NewGuid())
            git clone --quiet --depth 1 $RepoUrl $tmp
            if ($LASTEXITCODE -ne 0) { throw "Could not download $RepoUrl" }
            $installer = Join-Path $tmp "install.sh"
        }
        $targetPath = (Resolve-Path $Target).Path -replace '\\', '/'
        & $bash ($installer -replace '\\', '/') @Mode $targetPath
        if ($LASTEXITCODE -ne 0) { throw "Installation failed (exit code $LASTEXITCODE)." }
    } finally {
        if ($tmp -and (Test-Path $tmp)) { Remove-Item -Recurse -Force $tmp }
    }
} @args
