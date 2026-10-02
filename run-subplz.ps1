<#
  Runs SubPlz (https://github.com/kanjieater/SubPlz) through Docker on every
  audiobook folder under -Root, producing a read-along .srt next to each audio file.

  A folder is processed when it directly contains at least one audio file
  (.m4b/.mp3/...) and at least one text file (.epub/.txt).

  Usage (normally just double-click Run-SubPlz.bat):
    powershell -ExecutionPolicy Bypass -File run-subplz.ps1
    powershell -ExecutionPolicy Bypass -File run-subplz.ps1 -Root "D:\Books\Something" -Language ja
#>
param(
    [string]$Root = "C:\Users\Nebula PC\Downloads\Mushoku Tensei - Jobless Reincarnation",
    [ValidateSet("", "en", "ja")]
    [string]$Language = "",
    [string]$Model = "tiny",
    [switch]$Force,
    [switch]$DryRun
)

# "Continue" so stderr from docker (Windows PowerShell 5.1) is not treated as a fatal error
$ErrorActionPreference = "Continue"
$Image = "kanjieater/subplz:latest"
$ConfigDir = Join-Path $env:USERPROFILE "subplz-config"
$AudioExt = @(".m4b", ".mp3", ".m4a", ".aac", ".flac", ".ogg", ".opus", ".wav", ".mp4", ".mkv")
$TextExt = @(".epub", ".txt")

function Fail($msg) {
    Write-Host ""
    Write-Host "ERROR: $msg" -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

# --- 1. Check the folder ---------------------------------------------------
$Root = $Root.TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    Fail "Folder not found: $Root"
}
Write-Host "Audiobook folder: $Root" -ForegroundColor Cyan

# --- 2. Find book folders (audio + text side by side) ----------------------
$folders = @(Get-Item -LiteralPath $Root) + @(Get-ChildItem -LiteralPath $Root -Directory -Recurse)
$jobs = @()
foreach ($dir in $folders) {
    $files = @(Get-ChildItem -LiteralPath $dir.FullName -File)
    $audio = @($files | Where-Object { $AudioExt -contains $_.Extension.ToLower() } | Sort-Object Name)
    $text = @($files | Where-Object { $TextExt -contains $_.Extension.ToLower() } | Sort-Object Name)
    if ($audio.Count -eq 0 -and $text.Count -eq 0) { continue }

    $rel = $dir.FullName.Substring($Root.Length).TrimStart('\', '/')
    $label = if ($rel) { $rel } else { "(top folder)" }

    if ($audio.Count -eq 0 -or $text.Count -eq 0) {
        Write-Host "  SKIP  $label - needs both an audio file and an .epub/.txt (found $($audio.Count) audio, $($text.Count) text)" -ForegroundColor Yellow
        continue
    }
    if ($audio.Count -gt 1 -and $text.Count -ne $audio.Count) {
        Write-Host "  WARN  $label - $($audio.Count) audio files but $($text.Count) text file(s)." -ForegroundColor Yellow
        Write-Host "        This only works if the epub chapters line up with the audio files." -ForegroundColor Yellow
        Write-Host "        For best results merge the audio into one .m4b (e.g. AudioBookConverter)." -ForegroundColor Yellow
    }

    $done = @($audio | Where-Object { Test-Path -LiteralPath ([IO.Path]::ChangeExtension($_.FullName, ".srt")) })
    if (-not $Force -and $done.Count -eq $audio.Count) {
        Write-Host "  DONE  $label - subtitles already exist (use -Force to redo)" -ForegroundColor DarkGray
        continue
    }

    Write-Host "  OK    $label - $($audio.Count) audio, $($text.Count) text" -ForegroundColor Green
    $jobs += [pscustomobject]@{ Label = $label; Container = ("/media/" + $rel.Replace('\', '/')).TrimEnd('/') }
}

if ($jobs.Count -eq 0) {
    Fail "Nothing to process. Put each book's audio and its .epub/.txt together in the same folder."
}

# --- 3. Language -------------------------------------------------------------
if (-not $Language) {
    Write-Host ""
    $answer = Read-Host "Is the audiobook narrated in English or Japanese? [en/ja] (default en)"
    $Language = if ($answer.Trim().ToLower() -eq "ja") { "ja" } else { "en" }
}
Write-Host "Language: $Language   Model: $Model"

if ($DryRun) {
    Write-Host ""
    Write-Host "Dry run - would process:" -ForegroundColor Cyan
    $jobs | ForEach-Object { Write-Host "  $($_.Container)" }
    exit 0
}

# --- 4. Check Docker -------------------------------------------------------
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Fail "Docker is not installed. Install Docker Desktop (4.44.2 or newer) from https://www.docker.com/products/docker-desktop/ then run this again."
}
& docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "Docker Desktop is installed but not running. Start Docker Desktop, wait for it to say 'Engine running', then run this again."
}

Write-Host ""
Write-Host "Downloading/updating SubPlz (several GB the first time)..." -ForegroundColor Cyan
& docker pull $Image
if ($LASTEXITCODE -ne 0) { Fail "Could not download $Image" }

# --- 5. GPU check ------------------------------------------------------------
$gpuArgs = @()
$cuda = & docker run --rm --gpus all --entrypoint python $Image -c "import torch; print(torch.cuda.is_available())" 2>$null
if ($LASTEXITCODE -eq 0 -and "$cuda".Trim() -match "True$") {
    Write-Host "NVIDIA GPU detected - using it." -ForegroundColor Green
    $gpuArgs = @("--gpus", "all")
} else {
    Write-Host "No usable GPU found - running on CPU. This works but is much slower." -ForegroundColor Yellow
}

# --- 6. Run SubPlz ---------------------------------------------------------
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
$langArgs = if ($Language -eq "ja") { @() } else { @("--language", $Language) }
$failed = @()
$i = 0
foreach ($job in $jobs) {
    $i++
    Write-Host ""
    Write-Host "[$i/$($jobs.Count)] $($job.Label)" -ForegroundColor Cyan
    $dockerArgs = @("run", "--rm") + $gpuArgs + @(
        "-v", "${Root}:/media",
        "-v", "${ConfigDir}:/config",
        $Image, "sync", "-d", $job.Container, "--model", $Model
    ) + $langArgs
    & docker @dockerArgs
    if ($LASTEXITCODE -ne 0) { $failed += $job.Label }
}

# --- 7. Summary --------------------------------------------------------------
Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "All done! Each audio file now has a matching .srt next to it." -ForegroundColor Green
    Write-Host "Open the audio file in mpv (https://mpv.io) to read along."
} else {
    Write-Host "Finished with errors in:" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "Scroll up for the error message."
}
Read-Host "Press Enter to close"
