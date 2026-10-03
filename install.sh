#!/bin/sh
# Installs the Neko Raiden theme into OBS's user themes folder (Linux and macOS).
# Set OBS_THEMES_DIR to install somewhere else.
set -eu

here=$(cd "$(dirname "$0")" && pwd)

install_to() {
    dir=$1
    mkdir -p "$dir"
    rm -rf "$dir/NekoRaiden" "$dir/RaidenShogun" "$dir/RaidenShogun.ovt"
    cp "$here/NekoRaiden.ovt" "$dir/"
    cp -R "$here/NekoRaiden" "$dir/"
    echo "Installed to $dir"
}

if [ -n "${OBS_THEMES_DIR:-}" ]; then
    install_to "$OBS_THEMES_DIR"
else
    case "$(uname -s)" in
        Darwin)
            install_to "$HOME/Library/Application Support/obs-studio/themes"
            ;;
        *)
            install_to "${XDG_CONFIG_HOME:-$HOME/.config}/obs-studio/themes"

            flatpak="$HOME/.var/app/com.obsproject.Studio/config/obs-studio"
            if [ -d "$flatpak" ]; then
                install_to "$flatpak/themes"
            fi
            ;;
    esac
fi

echo "Restart OBS, then pick Settings > Appearance > Theme: Yami, Style: Neko Raiden."
