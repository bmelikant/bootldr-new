[bits 16]
[org 0x7c00]

%define LOAD_SEGMENT 	0x0050
%define LOAD_OFFSET  	0x0000
%define FSYS_SCRATCH  	0x7e00

_entry:

	jmp _boot

_bios_parameter_block:

	oem_label 			db 'mkdosfs '
	bytes_per_sector 	dw 512
	sectors_per_cluster	db 1
	reserved_sectors	dw 1
	fat_copies			db 2
	root_dir_entries	dw 224
	total_sectors_small	dw 2880
	media_descriptor	db 0xf0
	sectors_per_fat		dw 9
	sectors_per_track	dw 18
	heads_per_cylinder	dw 2
	reserved_sectors_lg	dd 0
	total_sectors_lg	dd 0
	drive_number		db 0
	reserved			db 0
	extended_boot_sig	db 0x29
	serial_number		dd 0xdeadbeef
	volume_label		db "OSBOOT DISK"
	file_system_id		db "FAT12   "

;-------------------------------------------------------------------------
; _clusterlba: convert a FAT12 cluster number to a Logical Block Address
;-------------------------------------------------------------------------
_clusterlba:

	sub ax,2
	xor cx,cx
	mov cl,byte [sectors_per_cluster]
	mul cx
	add ax,word [_first_data_sector]
	ret

;---------------------------------------------------------------------------
; _lbachs: convert a linear block address to cylinder-head-sector notation
;---------------------------------------------------------------------------
_lbachs:

	xor dx,dx
	div word [sectors_per_track]
	inc dl							; this is the sector number
	mov byte [_sector_number],dl	; store it

	xor dx,dx
	div word [heads_per_cylinder]
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
	mov dl,byte [drive_number]

	int 0x13
	jc .error

	mov si,s_msgProgress
	call _puts_16

	pop cx
	pop bx
	pop ax

	add bx,word [bytes_per_sector]
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

_read_root_dir_from_disk:

	; get the size of the root directory first and store it in cx
	xor dx,dx
	xor cx,cx
	mov ax,32
	mul word [root_dir_entries]
	div word [bytes_per_sector]
	xchg ax,cx

	; the root directory is located at the end of the FATs
	mov al,byte [fat_copies]
	mul word [sectors_per_fat]
	add ax,word [reserved_sectors]
	mov word [_first_data_sector],ax
	add word [_first_data_sector],cx

	mov bx,FSYS_SCRATCH
	call _readsectors

_locate_file:

	mov di,FSYS_SCRATCH
	mov cx,word [root_dir_entries]

.compare:

	push cx

	mov cx,11
	mov si,s_filenameStageTwo
	push di
	rep cmpsb
	pop di

	je _read_stage2

	pop cx
	add di,32
	loop .compare

	jmp _fatal

_read_stage2:

	; store the starting cluster
	mov dx,word [di+0x001a]
	mov word [_current_cluster],dx

	; read the first FAT into memory at the FSYS scratch address
	mov ax,word [reserved_sectors]
	mov cx,word [sectors_per_fat]
	mov bx,FSYS_SCRATCH
	
	call _readsectors

	mov ax,0x0050
	mov es,ax
	mov bx,0x0000

	push bx

_load_os_image:

	mov ax,word [_current_cluster]
	pop bx
	call _clusterlba

	xor cx,cx
	mov cl,byte [sectors_per_cluster]
	call _readsectors

	push bx

	; locate the next cluster

	mov ax,word [_current_cluster]
	mov cx,ax
	mov dx,ax
	shr dx,1
	add cx,dx

	mov bx,FSYS_SCRATCH
	add bx,cx
	mov dx,word [bx]
	test ax,0x01
	jnz .odd_cluster

.even_cluster:

	and dx,0x0fff
	jmp .cluster_done

.odd_cluster:

	shr dx,4

.cluster_done:

	mov word [_current_cluster],dx
	cmp dx,0x0ff0						; FAT EOF marker
	jb _load_os_image

.done:

	push word 0x0050
	push word 0x0000
	retf

	cli
	hlt


; variables / data area
_sector_number 		db 0
_head_number		db 0
_track_number		db 0
_current_cluster	dw 0
_first_data_sector	dw 0

; string table
s_msgStageOne 		db "LOAD STAGE2",13,10,0
s_msgDiskError		db "NON-SYSTEM DISK OR DISK ERROR",13,10,0
s_msgProgress		db ".",0
s_filenameStageTwo 	db "STAGE2  SYS"

times 510-($-$$) db 0
bootsig dw 0xaa55