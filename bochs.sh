#!/bin/bash
if [[ $EUID != 0 ]]; then
	echo 'This script must be run as root'
	exit 1
fi

if [ ! -f "floppy_a.img" ]; then
	./floppy.sh
fi

if [[ $? != 0 ]]; then
	echo 'Build script failed; aborting'
	exit 1
fi

bochs 'boot:floppy' 'floppya: 1_44=floppy_a.img,status=inserted' 'memory: guest=512,host=256'