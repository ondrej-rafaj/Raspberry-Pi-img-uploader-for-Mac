#!/bin/sh

#  main.sh
#  Raspberry Pi img uploader
#
#  Created by Ondrej Rafaj on 27/12/2012.
#  Copyright (c) 2012 Fuerte Innovations. All rights reserved.


echo "Starting"
exit

BSDNAME="/dev/$1"
IMGPATH="$2"
SUBDRIVES="$3"
IFS=:
ary=($SUBDRIVES)
for key in "${!ary[@]}"; do sudo hdiutil unmount "/dev/${ary[$key]}"; done


echo ${SUBDRIVESARR[@]}

sudo dd if=/Users/maxi/Projects/RaspBerry\ Pi/RasPiWrite-master/Gingerbread+EthernetManager.img of=/dev/disk1 bs=1m count=100

echo "Data: $BSDNAME - $IMGPATH - $SUBDRIVES - $SUBDRIVESARR!"