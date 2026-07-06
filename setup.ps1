# ================================================================
# PORTABLE AI USB SETUP - llama.cpp + MstyStudio Edition
# ================================================================
# Flow:
#   Read config (USB root)
#     -> Ensure llama.cpp exists (download latest release if missing)
#     -> Ensure MstyStudio exists (download latest release if missing)
#     -> Ensure selected model exists (download GGUF from HuggingFace if missing)
#     -> Start llama-server
#     -> Wait for local API to come up
#     -> Launch MstyStudio
#
# NOTE: Prefer running this via launch.bat sitting next to it. launch.bat
# requests Administrator rights once, up front (a single UAC prompt), so
# every step below - including trusting Caddy's local HTTPS certificate -
# already has admin rights and won't prompt a second time. Running this
# .ps1 directly still works; it'll just ask for elevation later, only if
# and when it's actually needed (Step 6).
# ================================================================

$ErrorActionPreference = "Continue"
$USB_Drive = Split-Path -Parent $MyInvocation.MyCommand.Path

# Always pause before the window closes - whether we're exiting cleanly,
# hitting a handled error, or catching an unexpected crash below. This is
# the single place every exit path in this script routes through.
function Stop-ScriptWithPause {
    param([int]$Code = 1)
    Write-Host ""
    if ($Code -eq 0) {
        Write-Host "Press any key to close this window..." -ForegroundColor Yellow
    } else {
        Write-Host "Something went wrong - press any key to close this window..." -ForegroundColor Yellow
    }
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
    exit $Code
}

try {

# Pull in the MstyStudio <-> llama.cpp integration helper (kept in its own file
# since it's a distinct concern from install/download logic).
$IntegrationHelper = Join-Path $USB_Drive "MstyStudio-integration.ps1"
if (Test-Path $IntegrationHelper) {
    . $IntegrationHelper
} else {
    Write-Host "  WARNING: MstyStudio-integration.ps1 not found next to setup.ps1 - integration check will be skipped." -ForegroundColor Yellow
}

# -----------------------------------------------------------------
# MODEL CATALOG
# -----------------------------------------------------------------
$ModelCatalog = @(
    @{
        Num      = 1
        Name     = "Qwen2.5 Coder 7B (Recommended)"
        File     = "Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf"
        URL      = "https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf"
        Size     = "4.68"
        MinBytes = 4500000000
        Local    = "qwen2.5-coder-7b"
        Label    = "RECOMMENDED"
        Badge    = "CODING"
        Prompt   = "You are Qwen2.5 Coder, an expert PHP, JavaScript, HTML/CSS, and WordPress developer assistant. Write clean, secure, well-documented code following WordPress coding standards where relevant, and explain your reasoning when it's not obvious."
    },
    @{
		Num      = 2
		Name     = "Phi-4 Mini Uncensored"
		File     = "phi_4_mini_uncensored.Q4_K_M.gguf"
		URL      = "https://huggingface.co/Melvin56/Phi-4-mini-instruct-abliterated-GGUF/resolve/main/phi-4-mini-instruct-abliterated-Q4_K_M.gguf"
		Size     = "2.49"
		MinBytes = 2450000000
		Local    = "phi4-mini-uncensored"
		Label    = "UNCENSORED"
		Badge    = "REASONING"
		Prompt   = "You are Phi-4 Mini Uncensored, a helpful, knowledgeable AI assistant. Provide accurate, clear, 
					and well-reasoned responses. Do not fabricate facts. When uncertain, state your uncertainty. 
					Follow the user's instructions while maintaining honesty and factual integrity."
    },
    @{
        Num      = 3
        Name     = "DeepSeek Coder V2 Lite"
        File     = "DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M.gguf"
        URL      = "https://huggingface.co/bartowski/DeepSeek-Coder-V2-Lite-Instruct-GGUF/resolve/main/DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M.gguf"
        Size     = "10.4"
        MinBytes = 9800000000
        Local    = "deepseek-coder-v2-lite"
        Label    = "STANDARD"
        Badge    = "FAST"
        Prompt   = "You are DeepSeek Coder V2 Lite, an expert coding assistant skilled across many languages including PHP, JavaScript, Python, and web development. Write clean, correct, well-explained code."
    },
    @{
        Num      = 4
        Name     = "Gemma 4 12B"
        File     = "Gemma-4-12B-it-IQ2_M.gguf"
        URL      = "https://huggingface.co/bartowski/gemma-4-12B-it-GGUF/resolve/main/gemma-4-12B-it-IQ2_M.gguf"
		#URL      = "https://huggingface.co/bartowski/gemma-4-12B-it-GGUF/resolve/main/gemma-4-12B-it-Q4_K_M.gguf"#
        Size     = "4.94 "
        MinBytes = 4700000000
        Local    = "gemma4-12b"
        Label    = "STANDARD"
        Badge    = "WRITING / UI"
        Prompt   = "You are Gemma."
    },
    @{
        Num      = 5
        Name     = "Phi-4 Mini 3.8B"
        File     = "microsoft_Phi-4-mini-instruct-Q4_K_M.gguf"
        URL      = "https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf"
        Size     = "2.49"
        MinBytes = 2400000000
        Local    = "phi4-mini"
        Label    = "STANDARD"
        Badge    = "GENERAL"
        Prompt   = "You are Phi-4 Mini, a fast, capable general-purpose and coding assistant."
    },
    @{
        Num      = 6
        Name     = "DeepSeek Coder V2 Lite Instruct"
        File     = "DeepSeek-Coder-V2-Lite-Instruct.Q4_K_M.gguf"
        URL      = "https://huggingface.co/QuantFactory/DeepSeek-Coder-V2-Lite-Instruct-GGUF/resolve/main/DeepSeek-Coder-V2-Lite-Instruct.Q4_K_M.gguf?download=true"
        Size     = "10.4"
        MinBytes = 9500000000
        Local    = "deepseek-coder-v2-lite"
        Label    = "STANDARD"
        Badge    = "CODING"
        Prompt   = "You are DeepSeek Coder, an expert programming assistant."
    },
    @{
        Num      = 7
        # NOTE: bartowski/Qwen2.5-Coder-7B-Instruct-GGUF and the official
        # Qwen/Qwen2.5-Coder-7B-Instruct-GGUF repo both serve the same
        # model at the same Q4_K_M quant - only one is included to avoid
        # a duplicate catalog entry.
        Name     = "Qwen2.5 Coder 7B Instruct"
        File     = "Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf"
        URL      = "https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf"
        Size     = "4.68"
        MinBytes = 4300000000
        Local    = "qwen2.5-coder-7b"
        Label    = "STANDARD"
        Badge    = "CODING"
        Prompt   = "You are Qwen2.5 Coder, a professional software engineering assistant."
    },
    @{
        Num      = 8
        Name     = "Qwen3 4B Thinking (Genius Coder)"
        File     = "rahul7star_Qwen3-4B-Thinking-2509-Genius-Coder-AI-Full-Q5_K_M.gguf"
        # Original link was a "/blob/main/" webpage URL, not a direct
        # download - converted to "/resolve/main/" so curl fetches the
        # raw file instead of an HTML page.
        URL      = "https://huggingface.co/rahul7star/Qwen3-4B-Thinking-2509-Genius-Coder-AI-Full/resolve/main/rahul7star_Qwen3-4B-Thinking-2509-Genius-Coder-AI-Full-Q5_K_M.gguf?download=true"
        Size     = "3.0"
        MinBytes = 2700000000
        Local    = "qwen3-4b-thinking-coder"
        Label    = "STANDARD"
        Badge    = "REASONING / CODING"
        Prompt   = "You are Qwen3 4B Thinking, a reasoning-focused coding assistant that thinks step by step before answering."
    },
    @{
        Num      = 9
        Name     = "Qwen2.5 Coder 14B Instruct"
        File     = "Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf"
        URL      = "https://huggingface.co/bartowski/Qwen2.5-Coder-14B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-14B-Instruct-Q4_K_M.gguf"
        Size     = "9.0"
        MinBytes = 8300000000
        Local    = "qwen2.5-coder-14b"
        Label    = "STANDARD"
        Badge    = "CODING (LARGE)"
        Prompt   = "You are Qwen2.5 Coder, an expert software engineering assistant."
    },
    @{
        Num      = 10
        Name     = "CodeLlama 13B Instruct"
        File     = "codellama-13b-instruct.Q4_K_M.gguf"
        URL      = "https://huggingface.co/TheBloke/CodeLlama-13B-Instruct-GGUF/resolve/main/codellama-13b-instruct.Q4_K_M.gguf"
        Size     = "7.9"
        MinBytes = 7300000000
        Local    = "codellama-13b-instruct"
        Label    = "STANDARD"
        Badge    = "CODING (LEGACY)"
        Prompt   = "You are CodeLlama, a helpful coding assistant specializing in PHP, HTML, and general-purpose programming."
    }
)

# -----------------------------------------------------------------
# NOTE: Replace every "<HF_DOWNLOAD_URL>" above with the real
# "resolve/main/....gguf" link from the model's HuggingFace page
# before running. The script will refuse to download placeholder
# URLs and will tell you which model needs fixing.
# -----------------------------------------------------------------

# -----------------------------------------------------------------
# CONFIG (read from USB root - config.json)
# -----------------------------------------------------------------
$ConfigPath = Join-Path $USB_Drive "config.json"

function Get-DefaultConfig {
    return [ordered]@{
        SelectedModel = 1
        Host          = "127.0.0.1"
        Port          = 8080
        ContextSize   = 4096
        GpuLayers     = 0
        ExtraServerArgs = ""
        ApiKey        = ""
        EnableHttpsProxy = $true
        ProxyPort     = 8443
    }
}

function Read-Config {
    if (-Not (Test-Path $ConfigPath)) {
        Write-Host "  No config.json found - creating a default one..." -ForegroundColor Yellow
        $default = Get-DefaultConfig
        $default | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8
        return [PSCustomObject]$default
    }
    try {
        $raw = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        return $raw
    } catch {
        Write-Host "  WARNING: config.json is invalid - falling back to defaults." -ForegroundColor Red
        return [PSCustomObject](Get-DefaultConfig)
    }
}

# Safely set a property on a config PSCustomObject, adding it if it doesn't
# already exist (needed for config.json files saved before a new setting,
# like ApiKey, was introduced).
function Set-ConfigValue {
    param($ConfigObj, [string]$Name, $Value)
    if ($ConfigObj.PSObject.Properties.Name -contains $Name) {
        $ConfigObj.$Name = $Value
    } else {
        $ConfigObj | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force
    }
}

# Generate a random alphanumeric token for --api-key.
function New-ApiKey {
    param([int]$Length = 40)
    $chars = (48..57) + (65..90) + (97..122)   # 0-9, A-Z, a-z
    -join (1..$Length | ForEach-Object { [char](Get-Random -InputObject $chars) })
}

# Best-effort detection of a LAN-facing IPv4 address, skipping loopback and
# link-local (APIPA) addresses. Returns $null if nothing suitable is found.
function Get-LanIPAddress {
    try {
        $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {
                $_.IPAddress -notlike "127.*" -and
                $_.IPAddress -notlike "169.254.*" -and
                $_.PrefixOrigin -ne "WellKnown"
            } |
            Select-Object -First 1 -ExpandProperty IPAddress
        return $ip
    } catch {
        return $null
    }
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# -----------------------------------------------------------------
# HELPER: Show the model catalog and prompt the user to pick one
# -----------------------------------------------------------------
function Show-ModelMenu {
    param($Catalog, [int]$CurrentSelection)

    Write-Host ""
    Write-Host "      Available models:" -ForegroundColor Cyan
    foreach ($m in $Catalog) {
        $marker = if ($m.Num -eq $CurrentSelection) { "*" } else { " " }
        Write-Host ("      [{0}] {1}. {2,-24} ~{3,-6}GB  [{4}] {5}" -f $marker, $m.Num, $m.Name, $m.Size, $m.Label, $m.Badge) -ForegroundColor White
    }
    Write-Host ""
    $choice = Read-Host "      Enter a model number to select it (Enter to keep current: $CurrentSelection)"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        return $CurrentSelection
    }

    $choiceNum = 0
    if ([int]::TryParse($choice, [ref]$choiceNum)) {
        $match = $Catalog | Where-Object { $_.Num -eq $choiceNum }
        if ($match) { return $choiceNum }
    }

    Write-Host "      Invalid selection - keeping current model ($CurrentSelection)." -ForegroundColor Yellow
    return $CurrentSelection
}

# -----------------------------------------------------------------
# HELPER: Verify a downloaded file is present and large enough
# -----------------------------------------------------------------
function Test-DownloadedFile {
    param([string]$Path, [long]$MinSize = 1000000)
    if (-Not (Test-Path $Path)) { return $false }
    return (Get-Item $Path).Length -gt $MinSize
}

# -----------------------------------------------------------------
# HELPER: Download a file with a couple of retries
# -----------------------------------------------------------------
function Get-FileWithRetry {
    param([string]$Url, [string]$Dest, [long]$MinBytes = 1000000, [int]$Attempts = 2)
    for ($i = 1; $i -le $Attempts; $i++) {
        if ($i -gt 1) { Write-Host "      Retry attempt $i..." -ForegroundColor Yellow }
        curl.exe -L --ssl-no-revoke --progress-bar $Url -o $Dest
        if (Test-DownloadedFile -Path $Dest -MinSize $MinBytes) { return $true }
    }
    return $false
}

# ================================================================
# START
# ================================================================
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   PORTABLE AI USB SETUP - llama.cpp +                 " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/7] Reading config from USB root..." -ForegroundColor Yellow
$Config = Read-Config
Write-Host "      Host:Port     : $($Config.Host):$($Config.Port)" -ForegroundColor DarkGray

# -------------------------------------------------------------
# Safety guard: only proceed silently on loopback. Anything else
# (e.g. Host set to 0.0.0.0 or a LAN IP) exposes the API beyond
# this PC and needs an explicit, typed confirmation.
# -------------------------------------------------------------
$LoopbackHosts = @("127.0.0.1", "localhost", "::1")
if ($LoopbackHosts -notcontains $Config.Host) {
    Write-Host ""
    Write-Host "  **********************************************************" -ForegroundColor Red
    Write-Host "  *  WARNING: Host is '$($Config.Host)', not loopback        " -ForegroundColor Red
    Write-Host "  **********************************************************" -ForegroundColor Red
    Write-Host "  This exposes the local AI API to your network, not just" -ForegroundColor Yellow
    Write-Host "  this PC - anyone on the same network could reach it." -ForegroundColor Yellow
    $confirm = Read-Host "  Type 'yes' to continue anyway, anything else to abort"
    if ($confirm -ne "yes") {
        Write-Host "  Aborted. Set Host back to 127.0.0.1 in config.json to run normally." -ForegroundColor Yellow
        Stop-ScriptWithPause 1
    }
}

# -------------------------------------------------------------
# Generate a persistent API key if one isn't set yet. This locks
# down llama-server so only clients that know the key (e.g. Msty,
# configured once) can hit the inference endpoints. /health stays
# public so this script's own readiness check keeps working.
# -------------------------------------------------------------
$NeedsSave = $false
if (-not ($Config.PSObject.Properties.Name -contains 'ApiKey') -or [string]::IsNullOrWhiteSpace($Config.ApiKey)) {
    Set-ConfigValue -ConfigObj $Config -Name 'ApiKey' -Value (New-ApiKey)
    $NeedsSave = $true
    Write-Host "      Generated a new API key for llama-server." -ForegroundColor Green
}
if (-not ($Config.PSObject.Properties.Name -contains 'EnableHttpsProxy')) {
    Set-ConfigValue -ConfigObj $Config -Name 'EnableHttpsProxy' -Value $true
    $NeedsSave = $true
}
if (-not ($Config.PSObject.Properties.Name -contains 'ProxyPort')) {
    Set-ConfigValue -ConfigObj $Config -Name 'ProxyPort' -Value 8443
    $NeedsSave = $true
}

$PickedModel = Show-ModelMenu -Catalog $ModelCatalog -CurrentSelection ([int]$Config.SelectedModel)
if ($PickedModel -ne [int]$Config.SelectedModel) {
    $Config.SelectedModel = $PickedModel
    $NeedsSave = $true
    Write-Host "      Saved model choice to config.json" -ForegroundColor Green
}

if ($NeedsSave) {
    $Config | ConvertTo-Json | Set-Content -Path $ConfigPath -Encoding UTF8
}
Write-Host "      SelectedModel : $($Config.SelectedModel)" -ForegroundColor DarkGray
Write-Host ""

New-Item -ItemType Directory -Force -Path "$USB_Drive\llama.cpp" | Out-Null
New-Item -ItemType Directory -Force -Path "$USB_Drive\MstyStudio" | Out-Null
New-Item -ItemType Directory -Force -Path "$USB_Drive\models" | Out-Null
New-Item -ItemType Directory -Force -Path "$USB_Drive\installer_data" | Out-Null

# =================================================================
# STEP 2: Ensure llama.cpp exists
# =================================================================
Write-Host "[2/7] Checking for llama.cpp..." -ForegroundColor Yellow

$LlamaDir    = "$USB_Drive\llama.cpp"
$LlamaServer = "$LlamaDir\llama-server.exe"

if (Test-Path $LlamaServer) {
    Write-Host "      llama.cpp found! Skipping download." -ForegroundColor Green
} else {
    Write-Host "      Not found. Fetching latest release info from GitHub..." -ForegroundColor Magenta
    try {
        $releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest" -Headers @{ "User-Agent" = "portable-ai-usb-setup" }
        # Prefer a plain CPU x64 Windows build so it runs on any machine without extra drivers
        $asset = $releaseInfo.assets | Where-Object { $_.name -match "bin-win-cpu-x64\.zip$" } | Select-Object -First 1
        if (-Not $asset) {
            # Fallback to any windows x64 zip if naming has changed
            $asset = $releaseInfo.assets | Where-Object { $_.name -match "win.*x64.*\.zip$" } | Select-Object -First 1
        }

        if ($asset) {
            $zipDest = "$LlamaDir\$($asset.name)"
            Write-Host "      Downloading $($asset.name) ($($releaseInfo.tag_name))..." -ForegroundColor Magenta
            if (Get-FileWithRetry -Url $asset.browser_download_url -Dest $zipDest -MinBytes 5000000) {
                Write-Host "      Extracting..." -ForegroundColor Yellow
                Expand-Archive -Path $zipDest -DestinationPath $LlamaDir -Force
                Remove-Item $zipDest -Force -ErrorAction SilentlyContinue
                # Some releases nest files in a subfolder - flatten if needed
                if (-Not (Test-Path $LlamaServer)) {
                    $found = Get-ChildItem -Path $LlamaDir -Filter "llama-server.exe" -Recurse | Select-Object -First 1
                    if ($found) { Copy-Item $found.FullName -Destination $LlamaDir -Force }
                }
                if (Test-Path $LlamaServer) {
                    Write-Host "      llama.cpp installed! ($($releaseInfo.tag_name))" -ForegroundColor Green
                } else {
                    Write-Host "      ERROR: llama-server.exe not found after extraction." -ForegroundColor Red
                }
            } else {
                Write-Host "      ERROR: Download of llama.cpp failed." -ForegroundColor Red
            }
        } else {
            Write-Host "      ERROR: Could not find a matching Windows asset in the latest release." -ForegroundColor Red
            Write-Host "      Check manually: https://github.com/ggml-org/llama.cpp/releases/latest" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "      ERROR: Could not reach GitHub to check llama.cpp releases." -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# =================================================================
# STEP 3: Ensure MstyStudio exists
# =================================================================
# NOTE: Msty Studio ships a Squirrel.Windows-style installer. Squirrel
# installers do NOT let you choose a custom install folder - they always
# land in %LocalAppData%\Programs\MstyStudio, and the real executable is
# named "MstyStudio.exe". Because of that, this step
# can't make the installer put MstyStudio directly on the USB drive. Instead:
#   1. Check if a portable copy already exists on the USB (fast path).
#   2. If MstyStudio is already installed locally, just copy it to the USB.
#   3. Otherwise, run the installer, let it install locally, then copy
#      the resulting folder onto the USB drive to make it portable.
#
# Squirrel sometimes nests the real exe one level down in a versioned
# folder (e.g. "app-1.2.3\MstyStudio.exe") instead of the app root, so
# every check below looks in the flat location first and falls back to
# a recursive search - same pattern used for llama-server.exe in Step 2.
# =================================================================
Write-Host ""
Write-Host "[3/7] Checking for MstyStudio..." -ForegroundColor Yellow

$MstyStudioDir       = "$USB_Drive\MstyStudio"
$MstyStudioExeName   = "MstyStudio.exe"
$MstyStudioExe       = "$MstyStudioDir\$MstyStudioExeName"
$MstyStudioLocalDir  = "$env:LOCALAPPDATA\Programs\MstyStudio"

# Verified against https://docs.msty.ai/studio/getting-started/download (Windows x64 link).
$MstyStudioURL = "https://next-assets.msty.studio/app/latest/win/MstyStudio_x64.exe"

function Find-MstyStudioExe {
    param([string]$SearchRoot, [string]$ExeName)
    if (-Not (Test-Path $SearchRoot)) { return $null }
    $flat = Join-Path $SearchRoot $ExeName
    if (Test-Path $flat) { return $flat }
    $found = Get-ChildItem -Path $SearchRoot -Filter $ExeName -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

$FoundOnUSB = Find-MstyStudioExe -SearchRoot $MstyStudioDir -ExeName $MstyStudioExeName

if ($FoundOnUSB) {
    $MstyStudioExe = $FoundOnUSB
    Write-Host "      MstyStudio found on USB! Skipping install." -ForegroundColor Green
} else {
    $FoundLocally = Find-MstyStudioExe -SearchRoot $MstyStudioLocalDir -ExeName $MstyStudioExeName

    if ($FoundLocally) {
        Write-Host "      MstyStudio is already installed locally - copying it to the USB drive..." -ForegroundColor Magenta
        Copy-Item -Path $MstyStudioLocalDir -Destination $MstyStudioDir -Recurse -Force
        $FoundOnUSB = Find-MstyStudioExe -SearchRoot $MstyStudioDir -ExeName $MstyStudioExeName
        if ($FoundOnUSB) {
            $MstyStudioExe = $FoundOnUSB
            Write-Host "      MstyStudio copied to USB!" -ForegroundColor Green
        } else {
            Write-Host "      ERROR: Copy to USB failed." -ForegroundColor Red
        }
    } else {
        $InstallerDest = "$USB_Drive\installer_data\MstyStudioSetup.exe"
        Write-Host "      Downloading MstyStudio installer..." -ForegroundColor Magenta
        if (Get-FileWithRetry -Url $MstyStudioURL -Dest $InstallerDest -MinBytes 10000000) {
            Write-Host ""
            Write-Host "  **********************************************************" -ForegroundColor Red
            Write-Host "  *  MstyStudio INSTALLER WILL OPEN NOW                     *" -ForegroundColor Red
            Write-Host "  **********************************************************" -ForegroundColor Red
            Write-Host "  MstyStudio's installer does NOT ask for an install location -" -ForegroundColor Yellow
            Write-Host "  it always installs to your local user profile. That's" -ForegroundColor Yellow
            Write-Host "  expected. Just let it finish; this script will copy it" -ForegroundColor Yellow
            Write-Host "  onto the USB drive automatically afterwards." -ForegroundColor Yellow
            Start-Process -FilePath $InstallerDest -Wait
            Remove-Item $InstallerDest -Force -ErrorAction SilentlyContinue

            $FoundLocally = Find-MstyStudioExe -SearchRoot $MstyStudioLocalDir -ExeName $MstyStudioExeName
            if ($FoundLocally) {
                Write-Host "      MstyStudio installed locally - copying to USB..." -ForegroundColor Magenta
                Copy-Item -Path $MstyStudioLocalDir -Destination $MstyStudioDir -Recurse -Force
                $FoundOnUSB = Find-MstyStudioExe -SearchRoot $MstyStudioDir -ExeName $MstyStudioExeName
                if ($FoundOnUSB) {
                    $MstyStudioExe = $FoundOnUSB
                    Write-Host "      MstyStudio is now portable on the USB drive!" -ForegroundColor Green
                } else {
                    Write-Host "      ERROR: Copy to USB failed after install." -ForegroundColor Red
                }
            } else {
                Write-Host "      WARNING: Could not find $MstyStudioExeName under $MstyStudioLocalDir after install." -ForegroundColor Yellow
                Write-Host "      The installer may still be finishing up, or install path has changed." -ForegroundColor Yellow
                Write-Host "      Check manually: https://msty.ai/studio/download" -ForegroundColor DarkGray
            }
        } else {
            Write-Host "      ERROR: MstyStudio installer download failed." -ForegroundColor Red
        }
    }
}

# =================================================================
# STEP 4: Ensure the selected model exists
# =================================================================
Write-Host ""
Write-Host "[4/7] Checking selected model..." -ForegroundColor Yellow

$SelectedNum = [int]$Config.SelectedModel
$Model = $ModelCatalog | Where-Object { $_.Num -eq $SelectedNum } | Select-Object -First 1

if (-Not $Model) {
    Write-Host "      ERROR: config.json SelectedModel=$SelectedNum does not match any catalog entry." -ForegroundColor Red
    Write-Host "      Valid values: $((($ModelCatalog | ForEach-Object { $_.Num }) -join ', '))" -ForegroundColor DarkGray
    Stop-ScriptWithPause 1
}

Write-Host "      Selected: $($Model.Name) (~$($Model.Size) GB) [$($Model.Label)]" -ForegroundColor White
$ModelPath = "$USB_Drive\models\$($Model.File)"

if (Test-DownloadedFile -Path $ModelPath -MinSize $Model.MinBytes) {
    Write-Host "      Model already downloaded! Skipping." -ForegroundColor Green
} elseif ($Model.URL -eq "<HF_DOWNLOAD_URL>") {
    Write-Host "      ERROR: No download URL set for '$($Model.Name)'." -ForegroundColor Red
    Write-Host "      Edit the `$ModelCatalog entry (Num=$($Model.Num)) and set its URL" -ForegroundColor DarkGray
    Write-Host "      to the GGUF 'resolve/main/...' link from HuggingFace." -ForegroundColor DarkGray
    Stop-ScriptWithPause 1
} else {
    Write-Host "      Downloading GGUF from Hugging Face... this may take a while." -ForegroundColor Magenta
    if (Get-FileWithRetry -Url $Model.URL -Dest $ModelPath -MinBytes $Model.MinBytes) {
        Write-Host "      Model download complete!" -ForegroundColor Green
    } else {
        Write-Host "      ERROR: Model download failed." -ForegroundColor Red
        Write-Host "      URL: $($Model.URL)" -ForegroundColor DarkGray
        Stop-ScriptWithPause 1
    }
}

# =================================================================
# STEP 5: Start llama-server
# =================================================================
Write-Host ""
Write-Host "[5/7] Starting llama-server..." -ForegroundColor Yellow

if (-Not (Test-Path $LlamaServer)) {
    Write-Host "      ERROR: llama-server.exe missing - cannot continue." -ForegroundColor Red
    Stop-ScriptWithPause 1
}

$ServerHost = $Config.Host
$ServerPort = $Config.Port
$ApiBase    = "http://${ServerHost}:${ServerPort}"

# If something is already listening on that port and responding, reuse it
$alreadyUp = $false
try {
    $r = Invoke-WebRequest -Uri "$ApiBase/health" -TimeoutSec 2 -UseBasicParsing
    if ($r.StatusCode -eq 200) { $alreadyUp = $true }
} catch {}

if ($alreadyUp) {
    Write-Host "      llama-server already running at $ApiBase - reusing it." -ForegroundColor Green
} else {
    $serverArgs = @(
        "-m", "`"$ModelPath`"",
        "--host", $ServerHost,
        "--port", $ServerPort,
        "-c", $Config.ContextSize,
        "-ngl", $Config.GpuLayers,
        "--api-key", $Config.ApiKey
    )
    if ($Config.ExtraServerArgs) {
        $serverArgs += ($Config.ExtraServerArgs -split "\s+")
    }

    $maskedArgs = $serverArgs -replace [regex]::Escape($Config.ApiKey), "********"
    Write-Host "      Launching: llama-server.exe $($maskedArgs -join ' ')" -ForegroundColor DarkGray
    Start-Process -FilePath $LlamaServer -ArgumentList $serverArgs -WindowStyle Hidden

    # -------------------------------------------------------------
    # STEP 5b: Wait for the local API to come up
    # -------------------------------------------------------------
    Write-Host "      Waiting for API at $ApiBase ..." -ForegroundColor Yellow
    $maxWaitSeconds = 90
    $waited = 0
    $isUp = $false

    while ($waited -lt $maxWaitSeconds) {
        try {
            $r = Invoke-WebRequest -Uri "$ApiBase/health" -TimeoutSec 2 -UseBasicParsing
            if ($r.StatusCode -eq 200) { $isUp = $true; break }
        } catch {}
        Start-Sleep -Seconds 2
        $waited += 2
        Write-Host "." -NoNewline -ForegroundColor DarkGray
    }
    Write-Host ""

    if ($isUp) {
        Write-Host "      llama-server is up! ($ApiBase)" -ForegroundColor Green
    } else {
        Write-Host "      WARNING: API did not respond within $maxWaitSeconds seconds." -ForegroundColor Red
        Write-Host "      MstyStudio will still launch, but you may need to check the model manually." -ForegroundColor Yellow
    }
}

# =================================================================
# STEP 6: Set up HTTPS access (Caddy reverse proxy)
# =================================================================
# llama-server's prebuilt Windows binary has no OpenSSL support built in,
# so it can only serve plain HTTP. To get a real https:// URL - on both
# 127.0.0.1 and the LAN IP - Caddy sits in front of it as a lightweight
# TLS-terminating reverse proxy and forwards to llama-server over loopback.
# llama-server itself keeps listening on 127.0.0.1 only; Caddy is the only
# thing actually exposed, so nothing talks to the model in plaintext except
# this one local hop.
# =================================================================
Write-Host ""
Write-Host "[6/7] Setting up HTTPS access (Caddy)..." -ForegroundColor Yellow

$FinalApiBase = $ApiBase
$LanApiBase   = $null

if (-not $Config.EnableHttpsProxy) {
    Write-Host "      EnableHttpsProxy is false in config.json - skipping. Using $ApiBase" -ForegroundColor DarkGray
} else {
    $CaddyDir  = "$USB_Drive\caddy"
    $CaddyExe  = "$CaddyDir\caddy.exe"
    New-Item -ItemType Directory -Force -Path $CaddyDir | Out-Null

    if (-Not (Test-Path $CaddyExe)) {
        Write-Host "      Caddy not found. Fetching latest release info from GitHub..." -ForegroundColor Magenta
        try {
            $caddyRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/caddyserver/caddy/releases/latest" -Headers @{ "User-Agent" = "portable-ai-usb-setup" }
            $caddyAsset = $caddyRelease.assets | Where-Object { $_.name -match "windows_amd64\.zip$" } | Select-Object -First 1

            if ($caddyAsset) {
                $caddyZip = "$CaddyDir\$($caddyAsset.name)"
                Write-Host "      Downloading $($caddyAsset.name) ($($caddyRelease.tag_name))..." -ForegroundColor Magenta
                if (Get-FileWithRetry -Url $caddyAsset.browser_download_url -Dest $caddyZip -MinBytes 5000000) {
                    Write-Host "      Extracting..." -ForegroundColor Yellow
                    Expand-Archive -Path $caddyZip -DestinationPath $CaddyDir -Force
                    Remove-Item $caddyZip -Force -ErrorAction SilentlyContinue
                    if (Test-Path $CaddyExe) {
                        Write-Host "      Caddy installed! ($($caddyRelease.tag_name))" -ForegroundColor Green
                    } else {
                        Write-Host "      ERROR: caddy.exe not found after extraction." -ForegroundColor Red
                    }
                } else {
                    Write-Host "      ERROR: Download of Caddy failed." -ForegroundColor Red
                }
            } else {
                Write-Host "      ERROR: Could not find a Windows amd64 asset in the latest Caddy release." -ForegroundColor Red
            }
        } catch {
            Write-Host "      ERROR: Could not reach GitHub to check Caddy releases." -ForegroundColor Red
            Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "      Caddy found! Skipping download." -ForegroundColor Green
    }

    if (Test-Path $CaddyExe) {
        $ProxyPort = $Config.ProxyPort
        $LanIP     = Get-LanIPAddress

        $proxyHosts = @("127.0.0.1")
        if ($LanIP) { $proxyHosts += $LanIP } else {
            Write-Host "      WARNING: Could not detect a LAN IP - HTTPS will only be reachable on this PC." -ForegroundColor Yellow
        }
        $siteAddresses = ($proxyHosts | ForEach-Object { "https://${_}:$ProxyPort" }) -join ", "

        $caddyfileContent = @"
{
    admin off
}

$siteAddresses {
    tls internal
    reverse_proxy $ServerHost`:$ServerPort
}
"@
        Set-Content -Path "$CaddyDir\Caddyfile" -Value $caddyfileContent -Encoding UTF8

        # Trust Caddy's local CA so browsers/Msty don't show a warning.
        # This step needs admin rights; we elevate just this one command.
        if (Test-IsAdministrator) {
            Write-Host "      Trusting Caddy's local CA (already elevated)..." -ForegroundColor Magenta
            & $CaddyExe trust 2>&1 | Out-Null
        } else {
            Write-Host "      Requesting admin rights to trust Caddy's local CA (UAC prompt)..." -ForegroundColor Magenta
            try {
                Start-Process -FilePath $CaddyExe -ArgumentList "trust" -Verb RunAs -Wait -ErrorAction Stop
            } catch {
                Write-Host "      WARNING: Could not auto-trust the CA (UAC declined or unavailable)." -ForegroundColor Yellow
                Write-Host "      HTTPS will still work, but you'll see a 'not trusted' warning until" -ForegroundColor Yellow
                Write-Host "      you manually run: $CaddyExe trust  (as Administrator)" -ForegroundColor DarkGray
            }
        }

        Write-Host "      Starting Caddy..." -ForegroundColor Magenta
        Start-Process -FilePath $CaddyExe -ArgumentList @("run", "--config", "Caddyfile", "--adapter", "caddyfile") -WorkingDirectory $CaddyDir -WindowStyle Hidden

        # Bypass cert validation for this readiness probe only - Caddy's cert
        # may not have finished propagating into the trust store yet, and this
        # is our own known local proxy, not an arbitrary external site.
        Add-Type -ErrorAction SilentlyContinue -TypeDefinition @"
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public class LocalProxyCertPolicy {
    public static bool Accept(object sender, X509Certificate cert, X509Chain chain, SslPolicyErrors errors) { return true; }
}
"@
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = [LocalProxyCertPolicy]::Accept

        Write-Host "      Waiting for HTTPS at https://127.0.0.1:$ProxyPort ..." -ForegroundColor Yellow
        $waited = 0
        $proxyUp = $false
        while ($waited -lt 30) {
            try {
                $r = Invoke-WebRequest -Uri "https://127.0.0.1:$ProxyPort/health" -TimeoutSec 2 -UseBasicParsing
                if ($r.StatusCode -eq 200) { $proxyUp = $true; break }
            } catch {}
            Start-Sleep -Seconds 2
            $waited += 2
            Write-Host "." -NoNewline -ForegroundColor DarkGray
        }
        Write-Host ""

        if ($proxyUp) {
            Write-Host "      HTTPS proxy is up!" -ForegroundColor Green
            $FinalApiBase = "https://127.0.0.1:$ProxyPort"
            if ($LanIP) { $LanApiBase = "https://${LanIP}:$ProxyPort" }
        } else {
            Write-Host "      WARNING: HTTPS proxy did not respond in time - falling back to $ApiBase" -ForegroundColor Red
        }
    } else {
        Write-Host "      Skipping HTTPS setup - Caddy is not available." -ForegroundColor Yellow
    }
}

# =================================================================
# STEP 7: Launch MstyStudio
# =================================================================
Write-Host ""
Write-Host "[7/7] Launching MstyStudio..." -ForegroundColor Yellow

if (Test-Path $MstyStudioExe) {
    Start-Process -FilePath $MstyStudioExe
    Write-Host "      MstyStudio launched." -ForegroundColor Green
    Write-Host "      In MstyStudio, point the model provider to: $FinalApiBase" -ForegroundColor DarkGray
} else {
    Write-Host "      ERROR: MstyStudio.exe not found - cannot launch." -ForegroundColor Red
    Write-Host "      Re-run this script after completing the MstyStudio install step." -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   SETUP COMPLETE                                          " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Model      : $($Model.Name)" -ForegroundColor White
Write-Host "  API (this PC): $FinalApiBase" -ForegroundColor White
if ($LanApiBase) {
    Write-Host "  API (LAN)  : $LanApiBase" -ForegroundColor White
}
Write-Host "  API Key    : $($Config.ApiKey)" -ForegroundColor White
Write-Host "  Config     : $ConfigPath" -ForegroundColor White
Write-Host ""
Write-Host "  In MstyStudio's model provider settings, set the API base" -ForegroundColor DarkGray
Write-Host "  to $FinalApiBase and paste the API key above as the Bearer token." -ForegroundColor DarkGray
if ($FinalApiBase -like "https://*" -and -not (Test-IsAdministrator)) {
    Write-Host "  If you see a certificate warning, it's Caddy's self-signed" -ForegroundColor DarkGray
    Write-Host "  local cert - click through it once, or run as Administrator" -ForegroundColor DarkGray
    Write-Host "  next time so the CA gets auto-trusted." -ForegroundColor DarkGray
}

Stop-ScriptWithPause 0

} catch {
    # Safety net for anything not already handled above (unexpected crash,
    # a cmdlet throwing, etc.) - guarantees the window still waits for a
    # keypress instead of vanishing before you can read the error.
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "   UNEXPECTED ERROR" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  $($_.InvocationInfo.PositionMessage)" -ForegroundColor DarkGray
    Stop-ScriptWithPause 1
}