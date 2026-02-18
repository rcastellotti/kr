# kr

Install:

```sh
curl -fsSL https://github.com/rcastellotti/kr/releases/latest/download/install.sh | sh
```

```powershell
irm https://github.com/rcastellotti/kr/releases/latest/download/install.ps1 | iex
```

Version/install-dir overrides:

```sh
curl -fsSL https://github.com/rcastellotti/kr/releases/latest/download/install.sh | sh -s -- --version v0.0.1 --bin-dir "$HOME/.local/bin"
```

```powershell
$env:KR_VERSION = "v0.0.1"
$env:KR_INSTALL_DIR = "$HOME\bin"
irm https://github.com/rcastellotti/kr/releases/latest/download/install.ps1 | iex
```

```sh
kr - micro KeyRing manager

Usage:
  kr <command> [arguments]

Commands:
  set <service> <user>    Save (or update) a password for the given service and user
  get <service> <user>    Retrieve a password for the given service and user
  del <service> <user>    Delete a password for the given service and user
  help                    Show this help message
```
