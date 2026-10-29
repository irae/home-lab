# Home lab stacks

- Host: `sheeta`; checkout: `/data/stacks`; persistent binds: `/data/volumes`.
- Host installation and layout: [INSTALL.md](INSTALL.md).
- Host services and image-update timer: [host/README.md](host/README.md).

## Services and ports

TCP ports below are Docker-published host ports. **Planned** and **Ready for setup**
entries are not running.
Use `http://sheeta:<port>/` on LAN and Tailscale.

| Stack / service | Host port | Container port | Host bind / access | Status |
| --- | --- | --- | --- | --- |
| [Dockge](dockge/README.md) | 5001 | 5001 | All interfaces; `http://sheeta:5001/` | Running |
| [Restricted mail](restricted-mail/README.md) | 5002 | 8080 | All IPv4 interfaces; `http://sheeta:5002/` | Running |
| [SABnzbd](sabnzbd/README.md) | 5003 | 8080 | All interfaces; `http://sheeta:5003/` | Running |
| [Set-brainz](set-brainz/README.md) | 5004 | 8765 | All interfaces; `http://sheeta:5004/` | Running |
| [Hermes web app](hermes/README.md) | 5005 | 9120 | All IPv4 interfaces; `http://sheeta:5005/` | Ready for setup |
| [Hermes dashboard](hermes/README.md) | 5006 | 9119 | All IPv4 interfaces; `http://sheeta:5006/` | Ready for setup |
| [Hermes API](hermes/README.md) | 8642 | 8642 | All IPv4 interfaces; `http://sheeta:8642/` | Ready for setup |
| [Local LLM sandbox](local-llm-sandboxed/README.md) | None | — | `docker exec -it local-llm-sandboxed bash` | Running |
| TSE 2026 DuckDB | None | — | Container/CLI; separate checkout in `tse-2026/` | Running |

- All-interface bindings are **not** Tailscale-only; existing stack bindings are unchanged.
- Hermes binds `0.0.0.0` for LAN and Tailscale access; `sheeta` resolves on both.
  Web/API authentication remains required.
- No router forwarding, public DNS, or public webhook ingress planned for Hermes.
- Keep this table updated when mappings change; recheck port availability before deployment.
- These entries describe stack mappings, not every host listener. SSH and Samba are
  host services; Samba configuration is in [host/samba/README.md](host/samba/README.md).
