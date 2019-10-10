[bits 16]
[org 0x7c00]

%define LOAD_SEGMENT 	0x0050
%define LOAD_OFFSET  	0x0000
%define FSYS_SCRATCH  	0x7e00

%define JMP_START				0x00
%define OEM_LABEL               0x03
%define BYTES_PER_SECTOR        0x0B
%define SECTORS_PER_CLUSTER     0x0D
%define RESERVED_SECTORS        0x0E
%define FAT_COPIES              0x10
%define ROOT_DIR_ENTRIES        0x11
%define TOTAL_SECTORS_SM        0x13
%define MEDIA_DESCRIPTOR        0x15
%define SECTORS_PER_FAT         0x16
%define SECTORS_PER_TRACK       0x18
%define HEADS_PER_CYLINDER      0x1A
%define RESERVED_SECTORS_LG     0x1C
%define TOTAL_SECTORS_LG        0x20
%define DRIVE_NUMBER            0x24
%define RESERVED                0x25
%define EXT_BOOT_SIG            0x26
%define SERIAL_NUMBER           0x27
%define VOLUME_LABEL            0x2B
%define FILESYSTEM_ID           0x36

%define BPBFIELD(x)     _bios_parameter_block+%+ x

_bios_parameter_block:

	jmp _boot
    resb 0x3A            ; the fat16 BPB is 60 bytes in length
    
_boot:

	cli
	xor ax,ax
	mov ds,ax
	mov es,ax

	mov ss,ax
	mov sp,0x9000
	mov sp,bp
	sti

	mov si,s_msgStageOne
	call _puts_16

	cli
	hlt
	
; boot-time routines

;-------------------------------------------------------------------------
; _clusterlba: convert a FAT12 cluster number to a Logical Block Address
;-------------------------------------------------------------------------
_clusterlba:

	sub ax,2
	xor cx,cx
	mov cl,byte [BPBFIELD(SECTORS_PER_CLUSTER)]
	mul cx
	add ax,word [_first_data_sector]
	ret

;---------------------------------------------------------------------------
; _lbachs: convert a linear block address to cylinder-head-sector notation
;---------------------------------------------------------------------------
_lbachs:

	xor dx,dx
	div word [BPBFIELD(SECTORS_PER_TRACK)]
	inc dl							; this is the sector number
	mov byte [_sector_number],dl	; store it

	xor dx,dx
	div word [BPBFIELD(HEADS_PER_CYLINDER)]
	mov byte [_track_number],al
	mov byte [_head_number],dl
	
	ret

;------------------------------------------------
; _readsectors: read file sectors from the disk
; CX: number of sectors to read, AX: starting sector
; ES:BX -> file read buffer
;------------------------------------------------
_readsectors:

	mov di,0x0005

.readloop:

	push ax
	push bx
	push cx

	call _lbachs
	
	mov ah,0x02
	mov al,0x01
	mov ch,byte [_track_number]
	mov cl,byte [_sector_number]
	mov dh,byte [_head_number]
	mov dl,byte [BPBFIELD(DRIVE_NUMBER)]

	int 0x13
	jc .error

	mov si,s_msgProgress
	call _puts_16

	pop cx
	pop bx
	pop ax

	add bx,word [BPBFIELD(BYTES_PER_SECTOR)]
	inc ax

	loop _readsectors
	ret

.error:

	xor ax,ax
	int 0x13
	
	pop cx
	pop bx
	pop ax

	dec di
	jnz .readloop

_fatal:

	mov si,s_msgDiskError
	call _puts_16

	cli
	hlt

;---------------------------------------------
; _puts_16: display a null-terminated string
;---------------------------------------------
_puts_16:

	lodsb
	or al,al
	jz .done

	mov ah,0x0e
	int 0x10
	jmp _puts_16

.done:

	ret

; data section

; strings
s_msgStageOne 	db 'LOADING OS...',13,10,0
s_msgProgress 	db '.',0
s_msgDiskError 	db 'DISK READ FAILURE',13,10,0

; variables
_track_number		db 0x00
_head_number		db 0x00
_sector_number		db 0x00
_first_data_sector  dw 0x0000

; waste the rest of the bytes up to 512 and boot signature
times 510-($-$$) db 0
dw 0xaa55