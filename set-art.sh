#!/bin/sh
# Puts your own image into one of the theme's artwork spots, then reinstalls the theme.
#
#   sh set-art.sh sources ~/Pictures/neko-raiden.png
#   sh set-art.sh mixer ./raiden.webp --opacity 0.8
#   sh set-art.sh scenes --reset
#
# Slots: scenes, sources, mixer, settings
# Options: --opacity <0.1-1>, --name <file.png>, --reset, --no-install
# Needs ImageMagick, or Python 3 with Pillow.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
theme="$here/NekoRaiden.ovt"
art="$here/NekoRaiden/art"

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-1}"
}

[ $# -ge 1 ] || usage
slot=$1
shift

case $slot in
    scenes)    selector='SceneTree';                    default='neko-raiden.png'; max='200x250' ;;
    sources)   selector='SourceTree';                   default='';                max='150x170' ;;
    mixer)     selector='#vMixerScrollArea';            default='sit.svg';         max='220x150' ;;
    settings)  selector='OBSBasicSettings #listWidget'; default='loaf.svg';        max='160x110' ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown slot '$slot' (use scenes, sources, mixer or settings)." >&2; exit 1 ;;
esac

image=''
opacity=1
name=''
reset=''
noinstall=''
while [ $# -gt 0 ]; do
    case $1 in
        --reset)      reset=1 ;;
        --no-install) noinstall=1 ;;
        --opacity)    opacity=${2:?--opacity needs a value}; shift ;;
        --name)       name=${2:?--name needs a value}; shift ;;
        -*)           echo "Unknown option $1" >&2; exit 1 ;;
        *)            image=$1 ;;
    esac
    shift
done

process() {
    if command -v magick >/dev/null 2>&1; then
        im=magick
    elif command -v convert >/dev/null 2>&1 && convert -version 2>/dev/null | grep -q ImageMagick; then
        im=convert
    else
        im=''
    fi

    if [ -n "$im" ]; then
        "$im" "$1" -alpha set -trim +repage -resize "$max>" \
            -channel A -evaluate multiply "$opacity" +channel "PNG32:$2"
        return
    fi

    py=''
    for candidate in python3 python; do
        if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import PIL' 2>/dev/null; then
            py=$candidate
            break
        fi
    done
    if [ -z "$py" ]; then
        echo "Needs ImageMagick, or Python 3 with Pillow (pip install pillow)." >&2
        exit 1
    fi
    "$py" - "$1" "$2" "$max" "$opacity" <<'EOF'
import sys
from PIL import Image

src, dst, size, opacity = sys.argv[1:5]
max_w, max_h = (int(v) for v in size.split("x"))
opacity = float(opacity)

img = Image.open(src).convert("RGBA")
bbox = img.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
if bbox:
    img = img.crop(bbox)
img.thumbnail((max_w, max_h), Image.LANCZOS)  # only ever shrinks
if opacity < 1:
    img.putalpha(img.getchannel("A").point(lambda a: int(a * opacity)))
img.save(dst)
EOF
}

if [ -n "$reset" ]; then
    file=$default
else
    if [ -z "$image" ]; then
        echo "Pass an image path or --reset." >&2
        exit 1
    fi
    file=${name:-custom-$slot.png}
    process "$image" "$art/$file"
    echo "Saved $file"
fi

if [ -n "$file" ]; then
    value="url(theme:NekoRaiden/art/$file)"
else
    value='none'
fi
if ! grep -q "^$selector {" "$theme"; then
    echo "Couldn't find the $slot artwork rule in NekoRaiden.ovt." >&2
    exit 1
fi
sed "/^$selector {/,/^}/ s|background-image: .*;|background-image: $value;|" "$theme" > "$theme.tmp"
mv "$theme.tmp" "$theme"
echo "$slot now uses $value"

if [ -z "$noinstall" ]; then
    sh "$here/install.sh"
fi
