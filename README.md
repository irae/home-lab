# Home lab

This is my personal self-hosted home lab: Docker Compose stacks, Debian host
setup, and scripts for keeping them running. I use it to experiment, learn,
automate parts of my personal life, and enjoy a few home-server utilities.
It's also a place to try persistent agents that keep state between sessions.

## Key highlights

- **Host hardening as an ongoing process.** I based the Debian setup on
  [sunknudsen's guides](https://github.com/sunknudsen/guides), then continued
  hardening and reviewing it through agent-assisted iteration. The
  [host operations docs](host/README.md) describe the controls tracked here and
  their limits, not a guarantee that the host is secure.
- **My own local-LLM sandbox design.** It runs Pi with local-model inference on
  separate, more capable hardware, rather than the server hosting these stacks.
  The intended application access is through restricted-mail. The current
  firewall permits broader private-network and Tailscale ranges, **not an
  exclusive mail-and-inference allowlist**; the
  [sandbox docs](local-llm-sandboxed/README.md) explain that boundary.
- **Deliberate local-model selection.** I keep the model, runtime, and
  hardware-specific evaluation process in
  [choose-a-local-llm](https://github.com/irae/choose-a-local-llm): inexpensive
  screening before more expensive tests, with measurements recorded per setup.
  Choosing a useful model and constraining the tools it can use are separate
  parts of the experiment.

## How I use it

Each stack has its own directory with a Compose configuration and notes for
setup, access, and updates. Application data lives in persistent storage outside
the checkout. Host-level scripts and systemd units handle operational tasks such
as patch installation, periodic reboots for kernel updates, and stack image updates.

I access services over the LAN or Tailscale. Published ports are not necessarily
Tailscale-only; access restrictions depend on each stack and the host network.
Container agent and coding sessions use existing unprivileged application
accounts, separate from root initialization and maintenance. Persistent agent
work, personal automation, and sandbox experiments don't all share the same
access policy.

These configurations are tailored to my setup, not a ready-to-run bundle for any
host. I review configuration and persistent data before deploying changes or
recreating containers. The per-stack docs separate configured protections from
what still needs checking on the running system.

## Documentation

- [Installation and layout](INSTALL.md) — host setup and storage conventions.
- [Host operations](host/README.md) — update automation, network choices, and
  host services.
- [LLM sandbox](local-llm-sandboxed/README.md) and
  [persistent agent setup](hermes/README.md) — design, access boundaries, and
  operation of the agent experiments.

Other stack directories contain their own setup and maintenance notes.
