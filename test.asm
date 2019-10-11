[bits 16]
[org 0x7c00]

%define ADJUSTSYM(x) 0x0600+(%+ x-0x7c00)

_boot:

	cli
	mov ax,0x1000
	mov ss,ax

	mov sp,0xb000
	xor ax,ax
	mov ds,ax
	mov es,ax
	sti

	; save DL (the boot drive number) on the stack
	push dx

	; source is our current code, destination is 0x0000:0x0600
	; we are just copying ourselves downward in memory
	mov si,0x7c00
	mov di,0x0600
	mov cx,0x200
	rep movsb

	; time to jump into our boot code proper
	push 0x00							; this is our new code segment
	push ADJUSTSYM(_boot_proper)		; this is our target address (where we copied ourselves)
	retf								; far return should take us to boot_proper

_boot_proper:

	; check for int13 extensions. we want to load using LBA instead of CHS so they MUST be present

	pop dx			; restore the boot drive number
	mov ah,0x41		; check for int13 extensions
	mov bx,0x55aa	; boot signature in bx
	int 0x13		; call the interrupt

	; if CF is clear and BX == 0xAA55 we are all good here
	jc _unsupported
	cmp bx,0xaa55
	jnz _unsupported

	mov si,ADJUSTSYM(s_msgSupported)
	mov bx,ADJUSTSYM(_puts16)
	call bx
	jmp _supported

_unsupported:

	mov si,ADJUSTSYM(s_msgInt13ExtNotSupported)
	mov bx,ADJUSTSYM(_puts16)
	call bx
	jmp $

_supported:

	; find the starting linear block address of the first bootable partition

_puts16:

	lodsb
	or al,al
	jz .done

	mov ah,0x0e
	int 0x10
	jmp _puts16

.done:

	ret

; strings section
s_msgBooting 				db 'BOOTING',13,10,0
s_msgInt13ExtNotSupported	db 'INT13 EXTENSIONS NOT SUPPORTED',13,10,0
s_msgSupported				db 'INT13 EXTENSIONS SUPPORTED',13,10,0

; data section
_disk_packet:
	times 24 db 0

# bochs ata0-master: type=disk, path="c.img", mode=flat