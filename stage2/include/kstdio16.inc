%ifndef _PUTS_16_INC
%define _PUTS_16_INC

%define VIDEO_MEMORY_SEGMENT 0xB800
%define CLEARSCREEN_COUNT 	2000
%define CLEARSCREEN_DATA	0x0720

_puts16:

	lodsb
	or al,al
	jz .done

	mov ah,0x0e
	int 0x10
	jmp _puts16

.done:

	ret

;--------------------
; Clear the display
;--------------------
_clrscr16:

	push ax
	push bx
	push cx

	mov ax,VIDEO_MEMORY_SEGMENT
	mov fs,ax
	xor bx,bx
	xor cx,cx
	mov cx,CLEARSCREEN_COUNT

.clear_loop:

	mov word [fs:bx],CLEARSCREEN_DATA
	inc bx
	inc bx
	loop .clear_loop

	call _reset_cursor

	pop cx
	pop bx
	pop ax

	ret

_reset_cursor:

	mov ah,0x02
	mov bh,0x0
	xor dx,dx
	int 0x10

	ret

%endif