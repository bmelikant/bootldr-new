[bits 16]
[org 0x0]

_entry:

	jmp _stage2

%include "include/kstdio16.inc"

_stage2:

	mov ax,0x0050
	mov ds,ax
	mov es,ax
	mov fs,ax
	mov gs,ax

	xor ax,ax
	mov ss,ax
	mov sp,0x9000
	mov bp,sp

	call _clrscr16
	
	mov si,s_msgStageTwoLoaded
	call _puts16

	cli
	hlt

s_msgStageTwoLoaded db 'Loaded bootloader stage2.sys',13,10,0

