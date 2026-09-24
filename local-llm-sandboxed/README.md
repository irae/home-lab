# local-llm-sandboxed

Pi (`@earendil-works/pi-coding-agent`) in Debian trixie.

The container user is `haku`, uid 1000. Host user `irae` has that uid, so volume files belong to `irae`.

`/data/volumes/local-llm-sandboxed` is bind-mounted on `/home/haku`. The directory is mode `0700`, owner `irae:irae`. Root and the Docker daemon can still read it.

The image has the current Debian packages `git`, `stow`, `git-delta`, `git-extras`, `jq`, `ripgrep`, `fd-find`, `python3`, and `python3-venv`. `fd-find` is linked as `fd`. Pi downloads `fd` and `rg` when they are missing, and this container has no path to GitHub. Node 24 comes from nvm at `/usr/local/nvm`. The build updates npm to latest, then runs `npm install -g --ignore-scripts @earendil-works/pi-coding-agent`.

## PDF

These read a text layer and open a PDF when the password is already known. They do not guess passwords. They do not OCR a scanned page.

Brazilian statements and bills use `R$`, dates as `DD/MM/YYYY`, a dot for thousands, and a comma for the decimal. `1.234,56` is one thousand two hundred thirty-four and fifty-six cents. Do not parse those amounts with an English float conversion.

Try the tools in this order. Stop when the text keeps the columns.

| Tool | Package | Use |
| --- | --- | --- |
| `pdfinfo` | `poppler-utils` | Page count, encryption, and whether a password is required. `pdfinfo -upw PASSWORD file.pdf` |
| `qpdf` | `qpdf` | Unlock and save a copy. `qpdf --password=PASSWORD --decrypt in.pdf out.pdf`. `qpdf --show-encryption file.pdf` shows the encryption. `qpdf --json file.pdf` dumps the object structure. |
| `pdftotext` | `poppler-utils` | First text read. `pdftotext -upw PASSWORD -layout -enc UTF-8 file.pdf -`. If columns break, try `pdftotext -bbox-layout -enc UTF-8 file.pdf out.xml` for word positions. |
| `pdftohtml` | `poppler-utils` | `pdftohtml -xml -enc UTF-8 file.pdf out.xml` when you need positions as XML. |
| `pdfimages` | `poppler-utils` | `pdfimages -list file.pdf`. A page with only a large image and no text needs OCR. Stop there. |
| `mutool` | `mupdf-tools` | `mutool draw -F stext -o out.xml file.pdf` writes structured text with positions. `mutool convert -o out.txt file.pdf` writes plain text. `mutool clean -p PASSWORD -D in.pdf out.pdf` rewrites an unlocked copy when `qpdf` refuses the file. |
| `gs` | `ghostscript` | Last resort rewrite. `gs -q -sPDFPassword=PASSWORD -sDEVICE=pdfwrite -o out.pdf in.pdf`. This builds a new PDF and can drop structure. |
| `pikepdf` | `python3-pikepdf` | Python wrapper for qpdf. `pikepdf.open(path, password=password)` then `save`. |
| `pypdf` | `python3-pypdf` | `PdfReader(path, password=password)` and `page.extract_text()`. Weak on columns. |
| `pdfminer` | `python3-pdfminer` | Layout-aware text. Use `extract_pages` when Poppler mixes columns. |
| `pymupdf` | `python3-pymupdf` | Import `pymupdf`. `doc.authenticate(password)` then `page.get_text("dict")` for blocks and coordinates. |

`pdftk` is not installed. `qpdf` covers the same unlock job without a Java runtime.

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
