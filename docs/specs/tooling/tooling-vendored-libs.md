# Vendored Libraries

This addon vendors third-party libraries under `Libs/` so it does not depend on another installed addon exposing them at runtime.

## Included

- `LibStub`
- `LibQTip-1.0`

## Source Policy

Libraries should be obtained from their official project pages or official release packages, then copied into this addon intentionally.

Do not treat another installed addon as the source of truth for shared libraries.

For `LibQTip-1.0`, prefer official project pages such as:

- CurseForge: <https://www.curseforge.com/wow/addons/libqtip-1-0>
- WowAce: <https://www.wowace.com/projects/libqtip-1-0>

## Maintenance Notes

- keep the vendored library load order explicit in the `.toc`
- preserve the original library folder names and file layout when updating
- update this file when the vendored library set changes
