# Home lab

This is my personal self-hosted home lab: Docker Compose stacks, host setup,
and scripts for keeping them running. I use it to experiment, learn, and automate
parts of my personal life, alongside a few useful home-server utilities.

## What I'm exploring

- **LLM sandboxing:** testing how to give agents useful tools while limiting their
  access. The local models run on separate, more capable hardware, not on the
  server hosting these stacks.
- **Persistent agents:** trying agents that keep state between sessions and can
  work on ongoing tasks.
- **Everyday automation:** finding small parts of my personal life worth
  automating, and trying them here.

## How I use it

Each stack has its own directory with a Compose configuration and notes for
setup, access, and updates. Application data lives in persistent storage outside
the checkout. Host-level scripts and systemd units handle operational tasks such
as image updates.

I access services over the LAN or Tailscale. Container agent and coding sessions
use existing unprivileged application accounts; root initialization and
maintenance are separate from normal agent work. The sandbox's access limits
are part of the experiment, not a guarantee of isolation.

These configurations are tailored to my setup, not a ready-to-run bundle for any
host. I review configuration and persistent data before deploying changes or
recreating containers.

## Documentation

- [Installation and layout](INSTALL.md) — host setup and storage conventions.
- [Host operations](host/README.md) — update automation and host services.
- [LLM sandbox](local-llm-sandboxed/README.md) and
  [persistent agent setup](hermes/README.md) — access, configuration, and
  operational details for the agent experiments.

Other stack directories contain their own setup and maintenance notes.
