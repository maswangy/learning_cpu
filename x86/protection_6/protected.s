#
# protected code.
#

.include "common.inc"

.code32
.section .text
.globl _start
_start:
    movw $KERNEL_DATA32_SELECTOR, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %ss
    movl $0x7ff0, %esp

    movw $TSS32_SELECTOR, %ax
    ltr %ax

    # set interrupt handler
    movl $GP_HANDLER_VECTOR, %esi
    movl $GP_handler, %edi
    call __set_interrupt_handler

    movl $PF_HANDLER_VECTOR, %esi
    movl $PF_handler, %edi
    call __set_interrupt_handler

    movl $DB_HANDLER_VECTOR, %esi
    movl $DB_handler, %edi
    call __set_interrupt_handler

    movl $AC_HANDLER_VECTOR, %esi
    movl $AC_handler, %edi
    call __set_interrupt_handler

    movl $UD_HANDLER_VECTOR, %esi
    movl $UD_handler, %edi
    call __set_interrupt_handler

    movl $NM_HANDLER_VECTOR, %esi
    movl $NM_handler, %edi
    call __set_interrupt_handler

    movl $TS_HANDLER_VECTOR, %esi
    movl $TS_handler, %edi
    call __set_interrupt_handler

    movl $OF_HANDLER_VECTOR, %esi
    movl $OF_handler, %edi
    call __set_user_interrupt_handler

    movl $BP_HANDLER_VECTOR, %esi
    movl $BP_handler, %edi
    call __set_user_interrupt_handler

    movl $BR_HANDLER_VECTOR, %esi
    movl $BR_handler, %edi
    call __set_user_interrupt_handler

code_entry:
    /*
     * copy code to 0x400000
     */
    movl $code_start, %esi
    movl $0x400000, %edi
    movl $code_end, %ecx
    subl %esi, %ecx
    rep movsb

    # enable sse
    movl %cr4, %eax
    btsl $9, %eax
    movl %eax, %cr4

    call pae_enable
    call xd_enable
    call init_pae32_paging
    
    movl $PDPT_BASE, %eax
    movl %eax, %cr3

    movl %cr0, %eax
    bts $31, %eax
    movl %eax, %cr0

/*
    movl $msg1, %esi
    call puts
    call println
    call println

    movl $msg2, %esi
    call puts
    call println
    movl $0x200000, %esi
    call dump_pae_page
    call println

    movl $msg4, %esi
    call puts
    call println
    movl $0x401000, %esi
    call dump_pae_page
    call println
*/

    movl $msg3, %esi
    call puts
    call println
    movl $0x400000, %esi
    call dump_pae_page
    call println

    ljmp $KERNEL_CODE32_SELECTOR, $0x400000

/*
    movl $msg5, %esi
    call puts
    call println
    movl $0x600000, %esi
    call dump_pae_page
    call println

    movl $msg6, %esi
    call puts
    call println
    movl $0x40000000, %esi
    call dump_pae_page

    jmp .
*/

code_start:
    movl $puts, %ebx
    movl $dump_pae_page, %edx

    movl $msg3, %esi
    call *%ebx
    movl $println, %eax
    call *%eax
    movl $0x400000, %esi
    call *%edx
    movl $println, %eax
    call *%eax

    jmp .
code_end:

msg1:   .asciz  "now: enable paging with PAE paging"
msg2:   .asciz  "----> dump virtual address: 0x200000 <----"
msg3:   .asciz  "----> dump virtual address: 0x400000 <----"
msg4:   .asciz  "----> dump virtual address: 0x401000 <----"
msg5:   .asciz  "----> dump virtual address: 0x600000 <----"
msg6:   .asciz  "----> dump virtual address: 0x40000000 <----"

###############################################################
# init_pae32_paging:
init_pae32_paging:
    movl $PDPT_BASE, %esi
    call clear_4k_page
    movl $0x201000, %esi
    call clear_4k_page
    movl $0x202000, %esi
    call clear_4k_page

    # PDPTE[0]
    movl $PDPT_BASE, %esi
    movl $0x201001, (%esi)
    movl $0x00, 4(%esi)
    # PDE[0] 0x00 ~ 0x1fffff (2M)
    # PDE[1] 0x200000 ~ 0x3fffff (2M)
    # PDE[2] 0x400000 ~ 0x400fff (4K)
    movl $0x201000, %esi
    movl $0x00, %eax
    movl $0x00000087, (%esi, %eax, 8)
    movl $0x00, 4(%esi, %eax, 8)
    inc %eax
    movl $0x00200087, (%esi, %eax, 8)
    movl $0x00, 4(%esi, %eax, 8)
    inc %eax
    movl $0x00202006, (%esi, %eax, 8)
    movl $0x00, 4(%esi, %eax, 8)
    # PTE[0] 0x400000 ~ 0x400fff (4K)
    movl $0x202000, %esi
    movl $0x00400000, (%esi)
    /*
    movl xd_bit, %eax
    movl %eax, 4(%esi)
    */
    ret

clear_4k_page:
    pxor %xmm1, %xmm1
    movl $4096, %eax
clear_4k_page_loop:
    movdqu %xmm1, -16(%esi, %eax, 1)
    movdqu %xmm1, -32(%esi, %eax, 1)
    movdqu %xmm1, -48(%esi, %eax, 1)
    movdqu %xmm1, -64(%esi, %eax, 1)
    movdqu %xmm1, -80(%esi, %eax, 1)
    movdqu %xmm1, -96(%esi, %eax, 1)
    movdqu %xmm1, -112(%esi, %eax, 1)
    movdqu %xmm1, -128(%esi, %eax, 1)
    sub $128, %eax
    jnz clear_4k_page_loop
    ret

xd_enable:
    movl $0x80000001, %eax
    cpuid
    btl $20, %edx
    movl $0x00, %eax
    jnc xd_enable_done
    movl $IA32_EFER, %ecx
    rdmsr
    bts $11, %eax
    wrmsr
    movl $0x80000000, %eax
xd_enable_done:
    movl %eax, xd_bit
    ret

pae_enable:
    movl $1, %eax
    cpuid
    btl $6, %edx
    jnc pae_enable_done
    movl %cr4, %eax
    bts $PAE_BIT, %eax
    movl %eax, %cr4
pae_enable_done:
    ret

###############################################################
# init_32bit_paging
# 0x000000-0x3fffff maped to 0x00 page frame using 4M page
# 0x400000-0x400fff maped to 0x400000 page frame using 4K page
init_32bit_paging:
    pushl %eax
    movl $PDT32_BASE, %eax
    movl $0x00000087, (%eax)    # set PDT[0]
    movl $0x00201001, 4(%eax)   # set PDT[1]
    movl $PTT32_BASE, %eax
    movl $0x00400001, (%eax)
    popl %eax
    ret

pse_enable:
    movl $1, %eax
    cpuid
    bt $3, %edx
    jnc pse_enable_done
    movl %cr4, %eax
    bts $4, %eax
    movl %eax, %cr4
pse_enable_done:
    ret

###############################################################
# set interrupt handler for kernel and user
# %esi : vector, %edi handler
.type __set_interrupt_handler, @function
__set_interrupt_handler:
    sidt __idt_pointer
    movl __idt_base, %eax
    movl %edi, 4(%eax, %esi, 8)
    movw %di, (%eax, %esi, 8)
    movw $KERNEL_CODE32_SELECTOR, 2(%eax, %esi, 8)
    movb $0x8e, 5(%eax, %esi, 8)
    ret

.type __set_user_interrupt_handler, @function
__set_user_interrupt_handler:
    sidt __idt_pointer
    movl __idt_base, %eax
    movl %edi, 4(%eax, %esi, 8)
    movw %di, (%eax, %esi, 8)
    movw $KERNEL_CODE32_SELECTOR, 2(%eax, %esi, 8)
    movb $0xee, 5(%eax, %esi, 8)
    ret

###############################################################
# GDT, IDT
__gdt_pointer:
    __gdt_limit:    .short  0x00
    __gdt_base:     .int    0x00

__idt_pointer:
    __idt_limit:    .short  0x00
    __idt_base:     .int    0x00


###############################################################
xd_bit:             .int    0x00

###############################################################
# include exception handler
.include "lib32.inc"
.include "handler.s"
.include "page32.s"

###############################################################
dummy:
    .space 0x1000-(.-_start), 0x00

