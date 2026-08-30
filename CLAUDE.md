# Neoterux's Dotfiles

In this repository are stored the configurations and dotfiles of @Neoterux
the structure of this repository is versioned as `v1`, `v2`, `v3`, etc.

The version only is upgraded when a configuration changed a lot that it would need
a new version, the old ones are immediatly marked as deprecated. The current version
is `v3`. For more information about this, you should read the [v3 CLAUDE.md](./v3/CLAUDE.md)
file.

All of the previous version can be marked as outdated and without support.

## System fixes

`etc/` mirrors system-wide config files (analogous to `usr/`) that aren't
tied to a dotfiles version. `scripts/` holds one-off apply scripts for them,
since these live outside $HOME and need root to install.

- `scripts/fix-sudo-delay.sh` — installs `etc/pam.d/system-auth`, which
  removes the multi-second delay sudo shows after a wrong password
  (pam_unix's built-in ~2s anti-bruteforce delay, replaced with an explicit
  0.5s one via pam_faildelay.so). Run it once per machine; it asks for sudo
  itself and backs up the original file first.