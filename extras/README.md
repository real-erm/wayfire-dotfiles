# Modular Extras Directory

This directory holds optional extension scripts and modular configurations that can be plugged into `main.sh`.

## Existing Modules
- `browser.sh`: Interactive or automated web browser installation (LibreWolf from official Arch `[extra]`, Firefox, Chromium).

## Adding Future Extras (e.g., Gaming with Wine/Lutris)
To add a new category (such as gaming):
1. Create a script (e.g., `extras/gaming.sh`).
2. Define a function (e.g., `install_gaming_extras()`) that checks prerequisites, enables `[multilib]` if required, and installs packages (`wine`, `lutris`, `steam`).
3. Call the function in `main.sh` during the extras stage.
