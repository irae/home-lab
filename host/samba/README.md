# LAN media share

This host-level Samba setup lets VLC on Apple TV play completed downloads without
exposing the downloader's whole configuration tree. NetBIOS and Bonjour provide
discovery without pinning a DHCP address. The configured NetBIOS name is `sheeta`;
discovery covers both onboard Ethernet ports.

Checking out these files does not activate them. Review the share and network
scope, then run `install-root.sh` as root. Inspect installed configuration and
services to establish what is actually active.

## Boundary and trade-offs

The [share definition](shares-available/sabnzbd.conf) is read-only guest access,
not authenticated private file access. Any permitted LAN client can read the
shared files. SMB signing and encryption are disabled for this compatibility
setup, so it does not provide cryptographic integrity or confidentiality against
an untrusted LAN. Keep sensitive material out of the share and don't expose this
service on a public or untrusted network.

The [global configuration](smb.conf) restricts listening interfaces and allowed
clients to loopback and the configured LAN CIDR. That is separate from Docker
and Tailscale service access. The guest session is forced to the Unix owner of
the download tree; narrowing the exported path and retaining `read only = yes`
are important because that account owns more than the exported files.

## Configuration choices

- Protocol: SMB2 minimum; SMB1 stays disabled. Guest read. No password.
- Name: NetBIOS `sheeta`, through `nmbd`. SMB1 stays off. NetBIOS is the name service, not the file dialect.
- Gate: `smbd` binds `lo` and the address in `192.168.1.0/24`. That address is on `enp1s0` or `enp2s0`, where the cable is. `hosts allow` is `127.0.0.1` and `192.168.1.0/24`.
- Do not put interface names in `interfaces`. Samba looks up a name with no address as a DNS name. Tailscale DNS takes 40 s to fail that lookup. Each Samba RPC process then starts late, and the Finder and VLC share list times out. A direct `smb://sheeta.local/sabnzbd` URL skips the share list when mDNS resolves the host.
- Bonjour: `avahi-daemon` on `enp1s0` and `enp2s0` only. `smbd` registers `_smb._tcp` through it. Finder and VLC on tvOS find `SHEETA` without NetBIOS.
- One share at a time. The selected share is the single link in `shares-enabled/`;
  installation copies it to the host. A repository link is not proof of live state.
- The tracked share is `sabnzbd`. Path: `/data/volumes/sabnzbd/config/Downloads/complete`.
- Do not share `/data/volumes/sabnzbd/config`. `sabnzbd.ini` holds server passwords and API keys.
- Guest file access uses Unix user `irae`, because that user owns the download tree.
- SMB signing is off. VLC guest sessions fail when the server requires signing.
- Mac and tvOS clients get the Apple SMB extensions: `vfs objects = fruit streams_xattr` in the global section, with the fruit options from the Samba Mac OS X wiki. `fruit:posix_rename` is not in this Samba build.

VLC lists the server in Local Network. The label is `SHEETA`. Open share `sabnzbd`. If VLC asks for a login, use the name `guest` and an empty password.

## Address changes and the second Ethernet port

The install script adds `allow-hotplug` DHCP for `enp2s0` alongside the primary
`enp1s0` setup. It does not run `ifup`. The second port comes up when a cable is
connected; a DHCP reservation for one port's MAC does not follow a cable move to
the other port.

A dhclient exit hook restarts `smbd` and `nmbd` when `enp1s0` or `enp2s0` gains an address, or when a renew changes the address. The NetBIOS registration then uses the new address. A restart drops an open playback. The old address is already gone in that case.

## Files

| File | Role |
| --- | --- |
| `smb.conf` | Global LAN rules and the NetBIOS name |
| `shares-available/sabnzbd.conf` | Share definition. Not live by itself |
| `shares-enabled/sabnzbd.conf` | Link that selects the one live share |
| `enable-share.sh` | Replace the link in the git tree. Does not install |
| `install-root.sh` | Install the package, copy config, start `smbd` and `nmbd` |
| `avahi-daemon.conf` | Limit Bonjour to the LAN ports |
| `dhclient-samba-netbios` | Re-register the name after an address change |
| `iface-enp2s0` | DHCP for the second port |

## Enable a different share later

1. Add `shares-available/<name>.conf`.
2. Run `bash /data/stacks/host/samba/enable-share.sh <name>`.
3. Review the new share path. Keep it off the app config directory when that directory holds secrets.
4. As root, run `bash /data/stacks/host/samba/install-root.sh`.

`enable-share.sh` deletes every other link in `shares-enabled/`.

## Install

Run as root:

```
bash /data/stacks/host/samba/install-root.sh
```

The script:

- installs Debian packages `samba` and `avahi-daemon` without recommended packages
- disables `samba-ad-dc` when that unit exists
- saves the original `/etc/samba/smb.conf` as `smb.conf.debian-original` once
- copies this tree into `/etc/samba`
- installs the dhclient hook and the `enp2s0` iface file
- saves the original `/etc/avahi/avahi-daemon.conf` as `avahi-daemon.conf.debian-original` once, then copies `avahi-daemon.conf`
- enables and starts `avahi-daemon`, `smbd`, and `nmbd`

Check:

```
nmblookup sheeta
smbclient -L 127.0.0.1 -N
systemctl status avahi-daemon smbd nmbd
```

Expect `nmblookup` to resolve the current LAN address and `smbclient -L` to list
`sabnzbd` promptly. Check playback/discovery from VLC as well as the CLI listing.
Verify a guest can read an intended media file but cannot write, cannot browse
application configuration, and cannot connect from a disallowed network. These
are deployment checks, not test results recorded here.

Changing to another share also requires reviewing the installer's `SHARE_PATH`
preflight: it currently checks the SABnzbd completion directory, independent of
the selected link. Selecting a new link alone does not generalize that check.

## Uninstall

```
systemctl disable --now smbd nmbd avahi-daemon
rm -f /etc/dhcp/dhclient-exit-hooks.d/samba-netbios
rm -f /etc/network/interfaces.d/enp2s0
rm -f /etc/samba/smb.conf /etc/samba/includes.conf
rm -rf /etc/samba/shares-available /etc/samba/shares-enabled
```

The files in this git directory stay. Restore `/etc/samba/smb.conf` from `smb.conf.debian-original` when you want the Debian file back. Restore `/etc/avahi/avahi-daemon.conf` from `avahi-daemon.conf.debian-original`. Package removal is separate: `apt-get remove samba avahi-daemon`.
