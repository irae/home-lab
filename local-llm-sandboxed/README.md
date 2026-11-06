# Local-LLM sandbox

This is my own sandbox design for experimenting with Pi
(`@earendil-works/pi-coding-agent`) and personal-life automation. Pi runs in a
Debian trixie container; local-model inference runs on separate, more capable
hardware, not on `sheeta`. The first intended application integration is
[restricted-mail](../restricted-mail/README.md), so the agent can work with a
limited mail interface rather than receive the Fastmail credential itself.

Model selection is a separate experiment, documented in
[choose-a-local-llm](https://github.com/irae/choose-a-local-llm): screen candidates,
then compare model/runtime configurations on the hardware that will run them.
No particular model or live Pi provider configuration is established by this
stack's tracked files.

## Design and limits

[Compose](compose.yaml) makes the image filesystem read-only, drops all
capabilities and adds back those needed by sshd, and sets `no-new-privileges`.
Temporary files use tmpfs; the application home remains writable and persistent.
There is no host Docker socket mount. These reduce available privileges and
accidental changes; they do not make a container a VM or protect the home volume
from the agent that owns it. Containers still share the host kernel.

**The current network rules are broader than the intended application access.**
The [host firewall script](sandbox-egress.sh) permits whole private-network and
Tailscale CIDRs, not only the mail app and inference endpoint. Other reachable
services in those ranges may be accessible. The rules also require a separate
host install; Compose alone does not enforce destination restrictions. See
[Network and egress](#network-and-egress) before running an agent.

## Users and persistent state

The image uses the existing `haku` account (uid 1000) for Pi, coding, and SSH sessions. Compose starts the SSH daemon as `root`; SSH permits only `haku`, with root login disabled. Plain `docker exec` still defaults to root, so normal use must explicitly select `haku` and its HOME. Interactive root Bash shells show a maintenance-only warning. Host user `irae` has uid 1000, so volume files belong to `irae`.

`/data/volumes/local-llm-sandboxed` is bind-mounted on `/home/haku`. Keep that
host directory mode `0700`, owned by `irae:irae`, and verify existing ownership
before making changes. Compose does not enforce those host permissions. Host
root and the Docker daemon can still read it; container root remains subject to
the reduced capability set.

The [Dockerfile](Dockerfile) installs coding tools and the PDF tools below at
build time. `fd-find` is linked as `fd`; including `fd` and `rg` avoids Pi needing
to download them at runtime. Direct public GitHub destinations are outside the
firewall's allowed CIDRs, but those rules do not exclude relays on allowed
networks. Node 24 comes from nvm at `/usr/local/nvm`. The build updates npm to
latest, then runs `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`.
The build has network access of its own; runtime egress restrictions are not a
build-time dependency or supply-chain policy.

## PDF workflow

These tools support document-processing experiments, including personal bills
and statements. Treat mail and attachments as untrusted input; limiting network
access does not prevent prompt injection or destructive edits inside the writable
home. Keep the original documents.

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

The home mount hides the image's `/home/haku`, so a copy there would not be
visible. The documented persistent-home setup uses `~/.dotfiles` as a symlink to
`/opt/dotfiles`, with Stow links for `bash`, `git`, `bin`, and `agents` pointing
through it. A rebuild replaces the image tree, not the home links. Inspect those
links on an existing volume; the entrypoint does not create them. `omarchy`,
`hypr`, `apps`, and `zsh` are not part of that Stow setup.

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

## Network and egress

Compose attaches the container to its own bridge and the external
`restricted-mail` network. Start the mail stack first so that network exists.
Both sandbox interface addresses are specified in [compose.yaml](compose.yaml)
and matched individually by [sandbox-egress.sh](sandbox-egress.sh); keep those
sources in sync if the network layout changes. The mail container is not a source
of these rules, and unrelated stacks are not intentionally filtered by them.

Host port 2201 is published on all IPv4 interfaces; no other host ports are
published. That is not a Tailscale-only binding. The documented inference endpoint
is `http://arrietty:8080/v1`, on the separate GPU machine; the mail app is
`http://restricted-mail:8080`. Pi's actual provider/model settings live outside
tracked configuration and must be checked in the persistent home. HTTP is not
transport encryption by itself.

The firewall's configured behavior is:

- `DOCKER-USER` sends forwarded traffic from either sandbox source to
  `SANDBOX-EGRESS`. Established/related traffic returns to Docker's rules.
- New destinations in `172.16.0.0/12` and `100.64.0.0/10` also return to Docker's
  rules; other forwarded destinations are dropped. There are no destination-port
  restrictions. This permits more than restricted-mail and model inference,
  subject to routing and the remaining firewall rules.
- Source-specific `mangle PREROUTING` rules drop new traffic addressed to the host
  before Docker can translate a published port. `SANDBOX-INPUT` also drops new
  host-input traffic from those sources; established/related replies are allowed.

These are IPv4 iptables rules. The dedicated bridge disables IPv6; the external
mail network is not declared IPv6-disabled here. Check actual network settings
and rule attachment on the host rather than assuming every traffic path is
covered. The oneshot unit is ordered after Docker, but does not itself verify or
continuously reconcile rules after Docker/firewall changes. The healthcheck only
runs `pi --version`; it does not test model availability or containment.

Mail permissions are another boundary: the app holds the Fastmail token, but its
allowlist/group policy is outside this checkout. Do not infer read-only mail
access from this container's network configuration.

### Install and enter

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

### Check the boundary after deployment

These are checks to perform, not results established by this README:

- Inspect `systemctl status local-llm-sandboxed-egress.service` and the installed
  `DOCKER-USER`, `INPUT`, and `mangle PREROUTING` rules. An active oneshot unit alone
  does not prove the rules still exist.
- From an unprivileged Pi session, check mail and model connectivity, an expected
  blocked destination, and host/published-port denial. Also check an unrelated
  stack still has its expected access. Review IPv6 separately if enabled.
- Verify key-only SSH, denied root/password login, an interactive PTY, and
  application HOME/ownership. Recheck state and SSH host-key persistence after a
  controlled recreation; audit work outside the home before replacing a container.
- Review the mail app's deployed policy and treat reachable services within the
  allowed CIDRs as part of the exposure, not as an exclusive endpoint allowlist.
