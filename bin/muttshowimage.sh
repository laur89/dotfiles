#! /bin/bash
# from http://paul.kuntke.de/blog/2012/07/16/view-images-in-mutt/

FONTH=14 # Size of one terminal row
FONTW=8  # Size of one terminal column

file="$1"
[[ -z "$file" ]] && exit
#### Determine size of Terminal
#height=`stty  size | awk 'BEGIN {FS = " "} {print $1;}'`
#width=`stty  size | awk 'BEGIN {FS = " "} {print $2;}'`
read height width <<< $(stty  size)
# alt: read width height <<< `echo -e "5;$FILENAME" | $W3MIMGDISPLAY`
#
### get the picture dimensions:
read w h <<< $(identify -format '%w %h' $file)

### convert to px
heightPx=$((height*14-100))
widthPx=$((width*7-250))
heightPx=$(($FONTH*$(($height-2))))
widthPx=$(($FONTW*$width))

if [[ "$h" -le "$heightPx" && "$w" -le "$widthPx" ]]; then
    width=$w
    height=$h
else
    # scale down
    newFile=/tmp/$RANDOM
    convert $file -scale ${widthPx}x${heightPx} $newFile
    file="$newFile"
    read width height <<< $(identify -format '%w %h' $file)
fi

### Display Image / offset with mutt bar
echo -e "2;3;\n0;1;210;20;$width;$height;0;0;0;0;$file\n4;\n3;" |  /usr/lib/w3m/w3mimgdisplay &
