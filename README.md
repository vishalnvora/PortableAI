# Portable AI USB — llama.cpp + MstyStudio

Run a local LLM straight off a USB drive on any Windows PC. One double-click
checks for everything it needs, downloads what's missing, and launches a
chat UI wired up to a local, HTTPS-secured inference server — no installs
on the host machine beyond one admin prompt, no internet required after
the first setup.

```
Run launch.bat (requests admin once, up front)
   ↓
Read config (USB root)
   ↓
Does llama.cpp exist?          → No → download latest release (GitHub)
   ↓
Does MstyStudio exist?         → No → download latest release (one-time manual install step)
   ↓
Does the selected model exist? → No → download GGUF from Hugging Face
   ↓
Start llama-server (127.0.0.1 only, protected by an API key)
   ↓
Wait for the local API to come up
   ↓
Set up HTTPS (Caddy reverse proxy, trusts its own local certificate)
   ↓
Launch MstyStudio
```

## What's in this folder

| File | Purpose |
|---|---|
| `launch.bat` | **Start here.** Requests admin rights once, then runs the script. |
| `setup.ps1` | The setup/launch script itself. Can be run directly, but `launch.bat` is recommended. |
| `config.json` | Your settings — which model to load, host/port, HTTPS, API key, etc. |
| `MstyStudio-integration.ps1` *(optional)* | Extra MstyStudio↔llama.cpp integration checks, auto-loaded if present. |

Running the script also creates, on first run:

```
USB_ROOT/
├── launch.bat
├── setup.ps1
├── config.json
├── llama.cpp/          ← llama-server.exe + DLLs
├── MstyStudio/           ← MstyStudio.exe (portable copy)
├── caddy/               ← caddy.exe + generated Caddyfile + local certs
├── models/              ← downloaded .gguf model files
└── installer_data/      ← temp installer downloads (auto-cleaned)
```

## Requirements

- Windows 10/11 (x64)
- PowerShell 5+ (built into Windows)
- Internet connection for the *first* run only. After that, everything
  runs offline from the USB drive.
- Free space on the USB drive for whichever model(s) you pick (see catalog
  below) plus roughly 1–2 GB for llama.cpp, MstyStudio, and Caddy combined.

## Quick start

1. Copy `launch.bat`, `setup.ps1`, and `config.json` to the root of your
   USB drive.
2. Open `config.json` and set `SelectedModel` to the number of the model
   you want (see catalog below) — or just leave it and pick interactively
   when the script runs.
3. Double-click **`launch.bat`**.
4. A UAC prompt appears once, right at the start — accept it. This lets
   every later step (including trusting the HTTPS certificate) run without
   asking again.
5. First run only:
   - llama.cpp and Caddy download and extract automatically.
   - MstyStudio's installer opens — it doesn't let you pick an install
     folder (it always installs to your local user profile), so just let
     it finish; the script copies it onto the USB automatically afterward.
   - The selected model downloads from Hugging Face.
   - Caddy generates and trusts a local HTTPS certificate automatically.
6. The script starts `llama-server`, waits for its API, brings up the
   HTTPS proxy, then launches MstyStudio.
7. At the end, the window prints your connection details and **waits for
   a keypress before closing** — nothing disappears before you can read it.
8. On future runs, all the checks pass instantly and it just starts the
   server, proxy, and MstyStudio.

## Connecting MstyStudio to the model

The script prints something like this at the end:

```
API (this PC): https://127.0.0.1:8443
API (LAN)    : https://192.168.1.23:8443
API Key      : a1B2c3D4...
```

In MstyStudio:

1. **Model Hub → Model Providers → Add Provider**
2. Choose the **OpenAI-compatible** ("bring your own endpoint") option
3. **Base URL**: the HTTPS address above **with `/v1` appended**, e.g.
   `https://127.0.0.1:8443/v1`
4. **API Key**: paste the key from the summary
5. Click **Fetch Models**, then **Save**

If you're connecting from a *different* device on the LAN, that device
won't automatically trust Caddy's certificate (trust is only set up on the
machine running the script) — you'll see a one-time "not trusted" warning
there, which is safe to accept since the connection is still encrypted.

## `config.json` reference

```json
{
    "SelectedModel": 1,
    "Host": "127.0.0.1",
    "Port": 8080,
    "ContextSize": 4096,
    "GpuLayers": 0,
    "ExtraServerArgs": "",
    "ApiKey": "",
    "EnableHttpsProxy": true,
    "ProxyPort": 8443
}
```

| Key | Meaning |
|---|---|
| `SelectedModel` | Number from the model catalog (below) to load. |
| `Host` / `Port` | Where `llama-server` itself listens. **Keep this at `127.0.0.1`** — the script will stop and ask for explicit confirmation (typing `yes`) if it's ever set to anything else, since that would expose the raw, unencrypted API beyond this PC. |
| `ContextSize` | Context window passed to llama-server as `-c`. |
| `GpuLayers` | Layers offloaded to GPU (`-ngl`). Leave at `0` for CPU-only. |
| `ExtraServerArgs` | Any extra flags appended verbatim to the `llama-server` command, e.g. `"--flash-attn"`. |
| `ApiKey` | Auto-generated on first run and saved here. Passed to `llama-server --api-key`; required by MstyStudio to authenticate. Clear it to `""` and re-run to rotate. |
| `EnableHttpsProxy` | If `true` (default), Caddy fronts llama-server with HTTPS. Set `false` to fall back to plain `http://127.0.0.1:8080` (e.g. for troubleshooting). |
| `ProxyPort` | The port Caddy's HTTPS listener uses. |

If `config.json` is missing, the script creates a default one automatically.
If it's malformed, it falls back to defaults. Older config files missing
newer fields (like `ApiKey`) get upgraded in place automatically.

## Model catalog

| # | Model | Size | Best for |
|---|---|---|---|
| 1 | Qwen3 Coder 1B | ~0.9 GB | Coding |
| 2 | Phi-4 Mini Uncensored | ~2.3 GB | Reasoning |
| 3 | DeepSeek Lite 1B | ~0.8 GB | Fast/lightweight |
| 4 | Gemma 4 12B (IQ2_M) | ~4.94 GB | Writing / UI |
| 5 | Phi-4 Mini 3.8B | ~2.49 GB | General use |
| 6 | DeepSeek Coder V2 Lite Instruct | ~10.4 GB | Coding |
| 7 | Qwen2.5 Coder 7B Instruct | ~4.68 GB | Coding |
| 8 | Qwen3 4B Thinking (Genius Coder) | ~3.0 GB | Reasoning / coding |
| 9 | Qwen2.5 Coder 14B Instruct | ~9.0 GB | Coding (large) |
| 10 | CodeLlama 13B Instruct | 7.9 GB | Coding (legacy, lower-end machines) |

Sizes for entries 6–9 are estimates based on typical quantization ratios —
worth a quick check against the actual file size on Hugging Face if
`MinBytes` ever flags a download as too small.

To add or edit a model, add an entry to the `$ModelCatalog` array near the
top of `setup.ps1` with a unique `Num`, the exact `.gguf` filename, its
direct Hugging Face `resolve/main/...` URL (not a `/blob/main/...` page
link — those need converting first), and a `MinBytes` sanity-check value
(roughly 90% of the real file size, used to catch truncated downloads).
Before adding a new one, check it isn't the same model/quant already in
the catalog under a different uploader.

## Setup notes

**llama.cpp** and **Caddy** download automatically via their GitHub
Releases APIs — no configuration needed.

**MstyStudio** doesn't expose a stable, scriptable "latest release" link,
so if the hardcoded installer URL in `setup.ps1` (`$MstyStudioURL`) ever
goes stale, grab the current one from
<https://msty.ai/studio/download> and update it there.

**Model URLs**: if you add a new catalog entry with a `<HF_DOWNLOAD_URL>`
placeholder, the script refuses to download it and tells you exactly which
entry needs fixing.

## Security notes

- `llama-server` only ever binds to `127.0.0.1` — it's never directly
  reachable from the network, even when HTTPS/LAN access is enabled.
- **Caddy** is the only thing actually exposed to the LAN (when
  `EnableHttpsProxy` is on); it terminates TLS and forwards to
  llama-server over loopback, so nothing talks to the model in plaintext
  except that one internal hop.
- **API key auth** is required on every real inference endpoint
  (`/completion`, `/v1/chat/completions`, etc.). `/health` and `/v1/models`
  stay public so the script's own readiness checks work without it.
- Changing `Host` away from loopback requires typing `yes` at a prompt —
  it won't happen silently via a config edit alone.

## Troubleshooting

- **Window closes instantly / can't read the output** — this shouldn't
  happen anymore: every exit path (success, handled errors, and even
  unexpected crashes) now pauses with "press any key to close this
  window..." before the window disappears. If it still closes immediately,
  it likely means PowerShell itself failed to launch — `launch.bat` now
  has its own fallback pause to catch that case too.
- **"llama-server.exe not found after extraction"** — GitHub's asset
  naming changed. Check
  <https://github.com/ggml-org/llama.cpp/releases/latest> manually and
  adjust the asset-matching pattern in Step 2.
- **"API did not respond within 90 seconds"** — the model may be too large
  for available RAM, or `GpuLayers` is set higher than your GPU supports.
  Try `GpuLayers: 0` and a smaller model.
- **MstyStudio.exe not found** — the installer likely hasn't finished, or
  installed to an unexpected path. Re-run `launch.bat`.
- **"Not trusted" certificate warning in MstyStudio or a browser** — on
  the machine running the script, this means the UAC prompt was declined
  (Caddy's CA never got trusted) — just re-run `launch.bat` and accept the
  prompt. On a *different* device connecting over the LAN, this is
  expected — that device never receives the trust step.
- **401 Unauthorized from the API** — the API key in MstyStudio's provider
  settings doesn't match `config.json`'s current `ApiKey`. Re-copy it from
  the script's final summary.
- **Download fails / file too small** — the script retries twice and
  checks file size against `MinBytes`. If it still fails, check the USB has
  enough free space and a stable connection, then re-run — completed
  downloads are skipped automatically.

## Notes on portability

Everything the script installs — llama.cpp, MstyStudio, Caddy, and the
model — lives under the USB root, so the same drive works on any Windows
PC without re-downloading anything. Re-running `launch.bat` on a new
machine just starts the server, proxy, and MstyStudio; nothing is written
outside the USB drive except MstyStudio's one-time local install (which
gets copied onto the USB automatically) and Caddy's trusted certificate
(a normal part of Windows' certificate store on that PC).
