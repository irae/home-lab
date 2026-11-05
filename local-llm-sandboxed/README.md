# local-llm-sandboxed

Pi (`@earendil-works/pi-coding-agent`) in Debian trixie.

The image uses the existing `haku` account (uid 1000) for Pi, coding, and SSH sessions. Compose starts the SSH daemon as `root`; SSH permits only `haku`, with root login disabled. Plain `docker exec` still defaults to root, so normal use must explicitly select `haku` and its HOME. Interactive root Bash shells show a maintenance-only warning. Host user `irae` has uid 1000, so volume files belong to `irae`.

`/data/volumes/local-llm-sandboxed` is bind-mounted on `/home/haku`. The directory is mode `0700`, owner `irae:irae`. Host root and the Docker daemon can still read it; container root remains subject to the reduced capability set.

The image has the current Debian packages `git`, `stow`, `git-delta`, `git-extras`, `jq`, `ripgrep`, `fd-find`, `python3`, and `python3-venv`. `fd-find` is linked as `fd`. Pi downloads `fd` and `rg` when they are missing, and this container has no path to GitHub. Node 24 comes from nvm at `/usr/local/nvm`. The build updates npm to latest, then runs `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`.

## PDF

The password is always provided. Do not guess it. Do not search for it.

Keep the original file. Write a second file with the password removed, and keep that unlocked file as the archive copy. Then read the unlocked file.

```bash
qpdf --password=PASSWORD --decrypt original.pdf archive.pdf
```

`qpdf` preserves the original content. Use `mutool clean -p PASSWORD -D original.pdf archive.pdf` only when `qpdf` refuses the file. Do not use `gs` for the archive copy. Ghostscript builds a new PDF and can drop structure.

These tools read a text layer. They do not OCR a scanned page.

Brazilian statements and bills use `R$`, dates as `DD/MM/YYYY`, a dot for thousands, and a comma for the decimal. `1.234,56` is one thousand two hundred thirty-four and fifty-six cents. Do not parse those amounts with an English float conversion.

Read the unlocked file in this order. Stop when the text keeps the columns.

| Tool | Package | Use |
| --- | --- | --- |
| `pdfinfo` | `poppler-utils` | Page count and a check that the archive copy has no password. `pdfinfo archive.pdf` |
| `qpdf` | `qpdf` | Write the archive copy. `qpdf --show-encryption original.pdf` shows the encryption before that. |
| `pdftotext` | `poppler-utils` | First text read of the archive copy. `pdftotext -layout -enc UTF-8 archive.pdf -`. If columns break, try `pdftotext -bbox-layout -enc UTF-8 archive.pdf out.xml` for word positions. |
| `pdftohtml` | `poppler-utils` | `pdftohtml -xml -enc UTF-8 file.pdf out.xml` when you need positions as XML. |
| `pdfimages` | `poppler-utils` | `pdfimages -list file.pdf`. A page with only a large image and no text needs OCR. Stop there. |
| `mutool` | `mupdf-tools` | `mutool draw -F stext -o out.xml archive.pdf` writes structured text with positions. `mutool convert -o out.txt archive.pdf` writes plain text. `mutool clean -p PASSWORD -D original.pdf archive.pdf` is the fallback unlock. |
| `gs` | `ghostscript` | Installed, but do not use it to make the archive copy. |
| `pikepdf` | `python3-pikepdf` | Python wrapper for qpdf. `pikepdf.open(path, password=password)` then `save`. |
| `pypdf` | `python3-pypdf` | `PdfReader(path, password=password)` and `page.extract_text()`. Weak on columns. |
| `pdfminer` | `python3-pdfminer` | Layout-aware text. Use `extract_pages` when Poppler mixes columns. |
| `pymupdf` | `python3-pymupdf` | Import `pymupdf`. `doc.authenticate(password)` then `page.get_text("dict")` for blocks and coordinates. |

`pdftk` is not installed. `qpdf` covers the same unlock job without a Java runtime.

## Dotfiles

The build copies `/home/irae/.dotfiles` to `/opt/dotfiles`. `.dockerignore` in that repo excludes `.git`. There is no startup copy.

The home mount hides `/home/haku`, so a copy there would not be visible. On the volume, `~/.dotfiles` is a symlink to `/opt/dotfiles`. Stow links (`bash`, `git`, `bin`, `agents`) point at that symlink. A rebuild replaces the tree in the image. The symlink stays. `omarchy`, `hypr`, `apps`, and `zsh` are not stowed.

Build on the host; the build reads `/home/irae`.

## Update

The image is built from the Dockerfile in this directory. There is no separate app checkout.

As `irae`, after `git pull` in `/data/stacks` when this directory changed:

```bash
cd /data/stacks/local-llm-sandboxed
docker compose up -d --build
```

`docker compose build` and `docker compose restart` leave the existing container on the old image. `up -d --build` replaces the container. The home volume stays.

The egress filter is a separate root install. An image rebuild does not run that step again. After `sandbox-egress.sh` changes, run `systemctl restart local-llm-sandboxed-egress.service` as root.

## SSH

The container runs OpenSSH on port 22; host port 2201 is published on all interfaces for LAN and Tailscale access. Connect with `ssh -p 2201 haku@sheeta`. Password authentication and root SSH login are disabled; the root daemon drops privileges to `haku` for sessions. Compose retains `CHOWN` so sshd can assign `/dev/pts/*` terminals to `haku`; SSH validation must include an interactive PTY (`ssh -tt`), not just remote commands. Authentication uses the existing public keys copied from `/home/irae/.ssh/authorized_keys` at build time. Add keys there and rebuild the image. Host keys persist in `/data/volumes/local-llm-sandboxed/ssh-hostkeys` across builds and container recreations.

## Network

The container has two fixed addresses:

| Address | Network |
| --- | --- |
| `172.30.70.10` | `local-llm-sandboxed` (`172.30.70.0/24`) |
| `172.19.0.250` | `restricted-mail` |

Host port 2201 is published on all interfaces; no other host ports are published. `pi` calls the GPU box at `http://arrietty:8080/v1`. The mail app is `http://restricted-mail:8080`.

## Egress

Compose has no destination limit. An internal network would also block the GPU box.

`DOCKER-USER` is an iptables chain Docker creates in the filter table. It is not a Compose field. Rules there run before Docker's own forward rules. A drop with no source match would hit every container.

`install-root.sh` installs a systemd unit. The unit runs `sandbox-egress.sh` after `docker.service`. The script creates chain `SANDBOX-EGRESS` and jumps there from `DOCKER-USER` for source `172.30.70.10` and source `172.19.0.250` only. Those chain names exist only in `sandbox-egress.sh`.

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

Enter with `docker exec -it --user haku --env HOME=/home/haku local-llm-sandboxed bash`, or launch Pi directly with `docker exec -it --user haku --env HOME=/home/haku local-llm-sandboxed pi`.

Use `docker exec -it --user root --workdir /root local-llm-sandboxed bash` only for deliberate maintenance, not agents. The read-only filesystem and reduced capabilities still apply to root; install system packages by rebuilding the image. Keep `/home/haku` user work owned by UID/GID 1000, but leave the root-owned `ssh-hostkeys` directory and private keys unchanged.

`DOCKER-USER` sees only forwarded traffic. Docker translates published ports before that chain, so they do not pass through `INPUT`. For both sandbox sources, the script drops traffic to host addresses in `mangle PREROUTING`, before that translation. Replies are allowed. Direct container and GPU access still uses the CIDR rules. The `INPUT` jumps to `SANDBOX-INPUT` also allow replies and drop other host traffic.
