# Submodules of droid-config-pdx246

When this repository is created (checked out at
`$ANDROID_ROOT/hybris/droid-configs`), add exactly one submodule:

| path | URL | pin | why |
|---|---|---|---|
| `droid-configs-device` | `https://github.com/mer-hybris/droid-hal-configs` | `1dae7f21ba676194f4cdafd6a6fc16d97462101d` (2026-09-18, "Merge pull request #303 from mer-hybris/jb64877", `git describe` 0.0.1-638-g1dae7f2) | The generic configuration every droid-config builds on: `droid-configs.inc` (the spec body), the base `sparse/` and `sparse-16/` trees, the pattern templates, `kickstart/` defaults, `sparse/boot/flash.sh` and `sparse/usr/sbin/flash-partition`. 1dae7f2 is the newest upstream commit (master head as checked in the adaptation map on 2026-10-04), it contains `sparse-16` (24c21ff "sparse: Add support for Android 16", 2025-11-19) and 37f2975 (droid-hal-init after systemd-modules-load), and it is the commit both reference checkouts use: `<sfos>/pdx235/droid-config-pdx235/droid-configs-device` and `<sfos>/pdx225/droid-config-pdx225/droid-configs-device` (`git submodule status`; `<sfos>` is the Sailfish OS workspace with the reference ports). Everything in this draft was checked against that tree. |

Commands (run in the new repository, after `git init`; the clone is a download
and is a download). The `.gitmodules` this creates is covered by REUSE.toml:

```sh
git submodule add https://github.com/mer-hybris/droid-hal-configs droid-configs-device
git -C droid-configs-device checkout 1dae7f21ba676194f4cdafd6a6fc16d97462101d
git add .gitmodules droid-configs-device
```

The resulting `.gitmodules`:

```
[submodule "droid-configs-device"]
	path = droid-configs-device
	url = https://github.com/mer-hybris/droid-hal-configs
```

Bumping the pin later: re-check `sparse-16/`. It is installed as a whole, and
this repository relies on its `disabled_services.rc`, `droid-bootctl.service`,
`droid-bootctl.sh` (also run by `pdx246-mark-slot.service`), `wait_for_keymint`,
`gbinder.conf` ApiLevel 36 and `dual-sim.conf`. Re-check the two pattern
templates as well (this repository's patterns were generated from them), and
`droid-configs.inc` (the file-splitting rules: paths containing `pulse`,
`/dconf/db/`, `flash-partition`, `platform-updates` go to subpackages; the files
in `out-of-image-files.files` go to `-out-of-image-files`).

There are no other submodules. In particular, no compiled SELinux policy is
vendored (see NOTES.md, decision D9).
