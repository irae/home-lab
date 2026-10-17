# LAN file share (Samba, NetBIOS name sheeta)

VLC on Apple TV plays files from an SMB share. This host answers the NetBIOS name `sheeta` on the LAN. The name stays when DHCP gives a new address, and when the cable moves from `enp1s0` to `enp2s0`.

Nothing here is live until you run `install-root.sh` as root.

## Decision

- Protocol: SMB2. Guest read. No password.
- Name: NetBIOS `sheeta`, through `nmbd`. SMB1 stays off. NetBIOS is the name service, not the file dialect.
- Gate: `smbd` binds `lo`, `enp1s0`, and `enp2s0`. `hosts allow` is `127.0.0.1` and `192.168.1.0/24`.
- One share at a time. The live share is the single link in `shares-enabled/`.
- First share: `sabnzbd`. Path: `/data/volumes/sabnzbd/config/Downloads/complete`.
- Do not share `/data/volumes/sabnzbd/config`. `sabnzbd.ini` holds server passwords and API keys.
- Guest file access uses Unix user `irae`, because that user owns the download tree.
- SMB signing is off. VLC guest sessions fail when the server requires signing.

VLC lists the server in Local Network. The label is `SHEETA`. Open share `sabnzbd`. If VLC asks for a login, use the name `guest` and an empty password.

## Why the second port is in this change

`enp1s0` is the port with DHCP today. `enp2s0` is the other onboard port. It has no address until a cable is in it. A router address pin follows the MAC, so a cable move gets a new address. The install script adds `allow-hotplug` DHCP for `enp2s0`. It does not run `ifup`. The port comes up when the cable is connected.

A dhclient exit hook restarts `smbd` and `nmbd` when `enp1s0` or `enp2s0` gains an address, or when a renew changes the address. The NetBIOS registration then uses the new address. A restart drops an open playback. The old address is already gone in that case.

## Files

| File | Role |
| --- | --- |
| `smb.conf` | Global LAN rules and the NetBIOS name |
| `shares-available/sabnzbd.conf` | Share definition. Not live by itself |
| `shares-enabled/sabnzbd.conf` | Link that selects the one live share |
| `enable-share.sh` | Replace the link in the git tree. Does not install |
| `install-root.sh` | Install the package, copy config, start `smbd` and `nmbd` |
| `dhclient-samba-netbios` | Re-register the name after an address change |
| `iface-enp2s0` | DHCP for the second port |

## Enable a different share later

1. Add `shares-available/<name>.conf`.
2. Run `bash /data/stacks/host/samba/enable-share.sh <name>`.
3. Review the new share path. Keep it off the app config directory when that directory holds secrets.
4. As root, run `bash /data/stacks/host/samba/install-root.sh`.

`enable-share.sh` deletes every other link in `shares-enabled/`.

## Install

Root SSH session:

```
bash /data/stacks/host/samba/install-root.sh
```

The script:

- installs Debian package `samba` without recommended packages
- disables `samba-ad-dc` when that unit exists
- saves the original `/etc/samba/smb.conf` as `smb.conf.debian-original` once
- copies this tree into `/etc/samba`
- installs the dhclient hook and the `enp2s0` iface file
- enables and starts `smbd` and `nmbd`

Check:

```
nmblookup sheeta
smbclient -L 127.0.0.1 -N
systemctl status smbd nmbd
```

`nmblookup` prints the current LAN address for `sheeta`.

## Uninstall

```
systemctl disable --now smbd nmbd
rm -f /etc/dhcp/dhclient-exit-hooks.d/samba-netbios
rm -f /etc/network/interfaces.d/enp2s0
rm -f /etc/samba/smb.conf /etc/samba/includes.conf
rm -rf /etc/samba/shares-available /etc/samba/shares-enabled
```

The files in this git directory stay. Restore `/etc/samba/smb.conf` from `smb.conf.debian-original` when you want the Debian file back. Package removal is separate: `apt-get remove samba`.
