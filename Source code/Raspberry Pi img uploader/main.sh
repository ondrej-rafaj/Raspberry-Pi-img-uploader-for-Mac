#!/bin/sh

#  main.sh
#  Raspberry Pi img uploader
#
#  Created by Ondrej Rafaj on 27/12/2012.
#  Copyright (c) 2012 Fuerte Innovations. All rights reserved.


echo "\n----------- Starting -----------"

BSDNAME="/dev/$1"
IMGPATH="$2"
SUBDRIVES="$3"
IFS=:
ary=($SUBDRIVES)
for key in "${!ary[@]}"; do sudo hdiutil unmount "/dev/${ary[$key]}"; done


echo ${SUBDRIVESARR[@]}
dd if=$IMGPATH of=$BSDNAME bs=1m count=100

echo "Data: $BSDNAME - $IMGPATH - $SUBDRIVES - $SUBDRIVESARR!\n"
echo "----------- Finished! -----------\n"