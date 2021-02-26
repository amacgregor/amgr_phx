#!/bin/bash

set -eu -o pipefail

ID=$1
TITLE=$2
BASE_IMAGE=$3 || "./assets/static/images/patterns/pattern-abstract-3.png"

mkdir ./assets/static/images/cards &>/dev/null || true

convert $BASE_IMAGE \
  \( -background none -fill white -size 320x -font ./assets/static/fonts/FiraCode-SemiBold.ttf \
     label:"allanmacgregor" \
  \) -gravity southeast -geometry +40+20 -compose over -composite \
  \( -background none -fill white -size 900x381 -font ./assets/static/fonts/Inter-SemiBold.otf \
     -size 900x381 caption:"$TITLE" \
  \) -gravity northeast -geometry +40+0 -compose over -composite \
  "./assets/static/images/cards/$ID.png"
