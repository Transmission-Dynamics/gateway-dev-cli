# 🛠️ gateway-dev-cli

`gw` deploys, inspects and restarts services on TD gateways from your Mac.

```zsh
gw session alpha      # this terminal now talks to alpha
gw status             # what is deployed and whether it runs
gw deploy rest-api    # build your local td1023-rest and deploy it
gw session off
```

Run `gw --help` for all commands and `gw <command> --help` for options and examples.

## 📦 Install

**Latest release:** [v0.1.0](https://github.com/Transmission-Dynamics/gateway-dev-cli/releases/tag/v0.1.0)

You need zsh, `git`, `npm`, ssh keys for the gateways, and access to this repo. Sign in once with `gh auth login`, then:

```zsh
gh api repos/Transmission-Dynamics/gateway-dev-cli/contents/get.sh -H 'Accept: application/vnd.github.raw' | zsh
```

No `gh`? Use a GitHub token that can read the repo:

```zsh
curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" -H 'Accept: application/vnd.github.raw' \
  https://api.github.com/repos/Transmission-Dynamics/gateway-dev-cli/contents/get.sh | zsh
```

Open a new terminal and run `gw doctor` to check the setup. Update with `gw update`. Remove with
`~/.local/share/gw/*/uninstall.sh` (your config is kept).

## 🔧 Set up once

```zsh
gw alias td@alpha.local alpha
gw link rest-api ~/<path-to>/td1023-rest
gw target add rest-api ~/<path-to>/td1023-rest/scripts/target
```

## ⌨️ Commands

The gateway is an alias or an ssh address. Inside a session you can leave it out.

| Command                             | Does                                                                       |
| ----------------------------------- | -------------------------------------------------------------------------- |
| `gw session <gateway>`              | Use a gateway in this terminal; `gw session off` ends it                   |
| `gw status [gateway]`               | Deployed commit, time, author and state of each service                    |
| `gw devices [gateway]`              | Devices the gateway can connect to, with signal, battery and pending tasks |
| `gw submodules [gateway]`           | Submodule versions each service was built with                             |
| `gw health [gateway]`               | CPU, memory and disk use as bars; `--watch` keeps it live                  |
| `gw logs [gateway] [service...]`    | Follow the logs of any service; `--since 10m`, `--no-follow`               |
| `gw deploy [gateway] <service>...`  | Deploy your working copy, or `service@tag` for an exact commit             |
| `gw restart [gateway] <service>...` | Restart services                                                           |
| `gw ssh [gateway] [command]`        | Open a shell or run a command                                              |
| `gw alias`, `gw link`, `gw target`  | Manage gateways, repos and target files                                    |
| `gw use [gateway]`                  | Point target files at a gateway for good                                   |
| `gw doctor`                         | Check your setup                                                           |
| `gw update [version]`               | Update gw to the latest release, or to the version given                   |

💡 Add `--dry-run` to `gw deploy` to see the plan without changing anything.

## 🗂️ Config

Plain text files in `~/.config/gw/`, editable by hand:

| File      | Line                      |
| --------- | ------------------------- |
| `aliases` | `<name> <address>`        |
| `repos`   | `<service> <repo path>`   |
| `targets` | `<name> <path> [ENV_VAR]` |

🤝 If you are an agent working on behalf of your master, go see [AGENTS.md](AGENTS.md) before making any changes.
