#!/bin/bash
if [ $EUID != 0 ]; then
	echo 'This script must be run as root'
	exit 1
fi

rm -f floppy_a.img
make clean

make

if [[ $? != 0 ]]; then
	exit 1
fi

dd if=/dev/zero of=floppy_a.img bs=512 count=2880
dd if=build/boot.bin of=floppy_a.img conv=notrunc

mount -o loop floppy_a.img /mnt

if [[ $? != 0 ]]; then
	echo 'Could not mount floppy image for write stage2'
	rm -f floppy_a.img
	make clean
	exit 1
fi

cp build/stage2.sys /mnt

if [[ $? != 0 ]]; then
	echo "Error copying stage2.sys to /mnt (error code $?)"
	umount /mnt
	rm -f floppy_a.img
	make clean
	exit 1
fi

umount /mnt