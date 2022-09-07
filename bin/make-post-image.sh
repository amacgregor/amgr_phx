#!/bin/bash

set -eu -o pipefail

ID=$1
TITLE=$2
BASE_IMAGE=$3 || "./priv/static/images/patterns/pattern-abstract-3.png"

mkdir ./priv/static/images/cards &>/dev/null || true

convert $BASE_IMAGE \
  \( -background none -fill white -size 320x -font ./priv/static/fonts/FiraCode-SemiBold.ttf \
     label:"allanmacgregor" \
  \) -gravity southeast -geometry +40+20 -compose over -composite \
  \( -background none -fill white -size 900x381 -font ./priv/static/fonts/Inter-SemiBold.otf \
     -size 900x381 caption:"$TITLE" \
  \) -gravity northeast -geometry +40+0 -compose over -composite \
  "./priv/static/images/cards/$ID.png"
