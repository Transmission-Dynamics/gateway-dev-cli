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

You need zsh, `git`, `npm` and ssh keys for the gateways.

```zsh
git clone <this repo> ~/repos/gateway-dev-cli
~/repos/gateway-dev-cli/install.sh
```

Open a new terminal and run `gw doctor` to check the setup. To update, `git pull`. To remove, `./uninstall.sh` (your config is kept).

## 🔧 Set up once

```zsh
gw alias td@alpha.local alpha
gw link rest-api ~/repos/td1023-rest
gw target add rest-api ~/repos/td1023-rest/scripts/target
```

## ⌨️ Commands

The gateway is an alias or an ssh address. Inside a session you can leave it out.

| Command | Does |
| --- | --- |
| `gw session <gateway>` | Use a gateway in this terminal; `gw session off` ends it |
| `gw status [gateway]` | Deployed commit, time, author and state of each service |
| `gw devices [gateway]` | Devices the gateway can connect to, with signal, battery and pending tasks |
| `gw submodules [gateway]` | Submodule versions each service was built with |
| `gw health [gateway]` | CPU, memory and disk use as bars; `--watch` keeps it live |
| `gw logs [gateway] [service...]` | Follow the logs of any service; `--since 10m`, `--no-follow` |
| `gw deploy [gateway] <service>...` | Deploy your working copy, or `service@tag` for an exact commit |
| `gw restart [gateway] <service>...` | Restart services |
| `gw ssh [gateway] [command]` | Open a shell or run a command |
| `gw alias`, `gw link`, `gw target` | Manage gateways, repos and target files |
| `gw use [gateway]` | Point target files at a gateway for good |
| `gw doctor` | Check your setup; every problem comes with the command that fixes it |

💡 Try `gw deploy alpha rest-api --dry-run` to see the plan without changing anything.

## 🗂️ Config

Plain text files in `~/.config/gw/`, editable by hand:

| File | Line |
| --- | --- |
| `aliases` | `<name> <address>` |
| `repos` | `<service> <repo path>` |
| `targets` | `<name> <path> [ENV_VAR]` |

Set `NO_COLOR=1` to turn colours and emojis off, or `GW_EMOJI=never` for emojis only. Exit codes: `0` ok, `1` failed, `2` wrong usage, `130` interrupted.

🤝 Working on gw: see [AGENTS.md](AGENTS.md).
