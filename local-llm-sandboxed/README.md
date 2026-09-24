# local-llm-sandboxed

Pi (`@earendil-works/pi-coding-agent`) in Debian trixie.

The container user is `haku`, uid 1000. Host user `irae` has that uid, so volume files belong to `irae`.

`/data/volumes/local-llm-sandboxed` is bind-mounted on `/home/haku`. The directory is mode `0700`, owner `irae:irae`. Root and the Docker daemon can still read it.

The image has the current Debian packages `git`, `stow`, `git-delta`, `git-extras`, `jq`, `ripgrep`, `python3`, and `python3-venv`. Node 24 comes from nvm at `/usr/local/nvm`. The build updates npm to latest, then runs `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`.

## Dotfiles

The build copies `/home/irae/.dotfiles` to `/opt/dotfiles`. `.dockerignore` in that repo excludes `.git`. There is no startup copy.

The home mount hides `/home/haku`, so a copy there would not be visible. On the volume, `~/.dotfiles` is a symlink to `/opt/dotfiles`. Stow links (`bash`, `git`, `bin`, `agents`) point at that symlink. A rebuild replaces the tree in the image. The symlink stays. `omarchy`, `hypr`, `apps`, and `zsh` are not stowed.

Build on the host. Dockge does not see `/home/irae`.

## Network

The container has two fixed addresses:

| Address | Network |
| --- | --- |
| `172.30.70.10` | `local-llm-sandboxed` (`172.30.70.0/24`) |
| `172.19.0.250` | `restricted-mail` |

No host ports. `pi` calls the GPU box at `http://arrietty:8080/v1`. The mail app is `http://restricted-mail:8080`.

## Egress

Compose has no destination limit. An internal network would also block the GPU box.

`DOCKER-USER` is an iptables chain Docker creates in the filter table. It is not a Compose field. Rules there run before Docker's own forward rules. A drop with no source match would hit every container.

`install-root.sh` installs a systemd unit. The unit runs `sandbox-egress.sh` after `docker.service`. The script creates chain `SANDBOX-EGRESS` and jumps there from `DOCKER-USER` for source `172.30.70.10` and source `172.19.0.250` only. That chain name exists only in `sandbox-egress.sh`.

The subnet keeps `172.30.70.10` stable. The match is those two addresses, not the subnet. `172.19.0.2` (the mail container) is not matched. Other stacks keep normal internet.

From those two addresses, `SANDBOX-EGRESS` allows `172.16.0.0/12` and `100.64.0.0/10`. Other destinations are dropped. `RETURN` hands the packet back to Docker's normal rules.

Run this as root before the first start:

```bash
bash /data/stacks/local-llm-sandboxed/install-root.sh
```

Then:

```bash
docker compose -f /data/stacks/local-llm-sandboxed/compose.yaml up -d
```

Enter with `docker exec -it local-llm-sandboxed bash`.

This filter sees forwarded traffic. Traffic to sheeta itself does not pass through `DOCKER-USER`.
