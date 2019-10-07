
all: stage1 stage2

stage2: stage2.sys

stage1: boot.bin

stage2.sys:
	nasm -I ./stage2/ stage2/stage2.asm -o build/stage2.sys -l stage2/stage2.lst -f bin

boot.bin:
	nasm stage1/stage1.asm -o build/boot.bin -l stage1/boot.lst -f bin

clean:
	rm -f build/boot.bin stage1/boot.lst build/stage2.sys stage2/stage2.lst