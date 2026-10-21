# appimage-sync

Automatically turns AppImages in `~/Applications` into regular desktop entries, so they show up in the GNOME app grid (or any freedesktop-compliant launcher) without a manager app.

It has two parts: a systemd **user** path unit that watches the folder, and a small Bash script that keeps `~/.local/share/applications` in sync with what is in it. Add an AppImage and it appears in the launcher. Delete it and the entry goes away.

## Files

| File | Install location | Purpose |
|------|------------------|---------|
| `appimage-sync` | `~/.local/bin/appimage-sync` | Sync script |
| `appimage-sync.service` | `~/.config/systemd/user/` | Oneshot service that runs the script |
| `appimage-sync.path` | `~/.config/systemd/user/` | Watches `~/Applications` and starts the service on changes |

## Installation

```bash
install -Dm755 appimage-sync ~/.local/bin/appimage-sync
install -Dm644 appimage-sync.service appimage-sync.path -t ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now appimage-sync.path
systemctl --user start appimage-sync.service   # initial sync of existing AppImages
```

From then on, drop `*.AppImage` files into `~/Applications`.

## How it works

1. `appimage-sync.path` uses `PathChanged=%h/Applications`. systemd fires when a file in the folder is created, deleted, renamed, or closed after writing, so half-finished downloads don't trigger it early.
2. The path unit starts `appimage-sync.service`, a `Type=oneshot` that runs the script.
3. The script:
   - **Cleans up**: removes any `appimage-*.desktop` entry whose `X-AppImage-Path=` points to a file that no longer exists.
   - **Integrates** every `*.AppImage` (matched case-insensitively) in `~/Applications`:
     - sets the executable bit;
     - skips the file if its `.desktop` entry is newer than the AppImage (already up to date);
     - extracts only the embedded `.desktop` file using `--appimage-extract '*.desktop'`, so it doesn't unpack the whole image;
     - reads its `Icon=` value and extracts the matching icon file from the AppImage root;
     - writes `~/.local/share/applications/appimage-<filename>.desktop` with `Exec=` pointing to the AppImage (field codes like `%U` are kept), `Icon=` pointing to the copied icon, `TryExec=` removed, and an `X-AppImage-Path=` marker added;
   - runs `update-desktop-database` so MIME associations are picked up.

Icons are stored in `~/.local/share/icons/appimage/`.

## Configuration

The paths are variables at the top of the script:

```bash
SRC="$HOME/Applications"                      # folder to watch
APPS="$HOME/.local/share/applications"        # where .desktop files go
ICONS="$HOME/.local/share/icons/appimage"     # where icons go
```

If you change `SRC`, update `PathChanged=` in `appimage-sync.path` to match, then run `systemctl --user daemon-reload`.

## Updating an AppImage

Replace the file. If the filename stays the same, the newer modification time triggers a fresh extraction. If the filename changes (e.g. a version number in the name), the old entry is removed as stale and a new one is created.

## Troubleshooting

```bash
systemctl --user status appimage-sync.path appimage-sync.service
journalctl --user -u appimage-sync.service -e      # script output
systemctl --user start appimage-sync.service       # force a sync
```

- **"no .desktop in X.AppImage"**: the AppImage either has no embedded desktop file or uses an old type-1 runtime that doesn't support `--appimage-extract <pattern>`. Write a desktop entry for it by hand.
- **Entry doesn't show up in GNOME**: new files in `~/.local/share/applications` are usually picked up right away. If not, reopen the app grid or log out and back in.
- **Generic icon**: the `Icon=` name in the embedded desktop file didn't match a file at the AppImage root. The entry still works; copy an icon into `~/.local/share/icons/appimage/` and point `Icon=` at it.
- **Forcing re-extraction**: delete the corresponding `appimage-*.desktop` file, or `touch` the AppImage, then run the service.

## Limitations

- Only the top level of the folder is watched; subdirectories are ignored.
- Only entries created by this script (prefix `appimage-`) are ever removed; other desktop files are not touched.
- No update management, sandboxing or signature checking: AppImages run exactly as they would from a terminal.
- Extraction needs no FUSE, but running the AppImages themselves still does (e.g. `libfuse2`), as usual.

## Uninstall

```bash
systemctl --user disable --now appimage-sync.path
rm ~/.config/systemd/user/appimage-sync.{path,service} ~/.local/bin/appimage-sync
systemctl --user daemon-reload

# optional: remove generated entries and icons
rm ~/.local/share/applications/appimage-*.desktop
rm -r ~/.local/share/icons/appimage
update-desktop-database ~/.local/share/applications
```