/*
            Copyright Oliver Kowalke 2009.
   Distributed under the Boost Software License, Version 1.0.
      (See accompanying file LICENSE_1_0.txt or copy at
            http://www.boost.org/LICENSE_1_0.txt)
*/

/****************************************************************************************
 *                                                                                      *
 *  ----------------------------------------------------------------------------------  *
 *  |    0    |    1    |    2    |    3    |    4     |    5    |    6    |    7    |  *
 *  ----------------------------------------------------------------------------------  *
 *  |   0x0   |   0x4   |   0x8   |   0xc   |   0x10   |   0x14  |   0x18  |   0x1c  |  *
 *  ----------------------------------------------------------------------------------  *
 *  | fc_mxcsr|fc_x87_cw|        R12        |         R13        |        R14        |  *
 *  ----------------------------------------------------------------------------------  *
 *  ----------------------------------------------------------------------------------  *
 *  |    8    |    9    |   10    |   11    |    12    |    13   |    14   |    15   |  *
 *  ----------------------------------------------------------------------------------  *
 *  |   0x20  |   0x24  |   0x28  |  0x2c   |   0x30   |   0x34  |   0x38  |   0x3c  |  *
 *  ----------------------------------------------------------------------------------  *
 *  |        R15        |        RBX        |         RBP        |        RIP        |  *
 *  ----------------------------------------------------------------------------------  *
 *                                                                                      *
 ****************************************************************************************/

# if defined __CET__
#  include <cet.h>
#  define SHSTK_ENABLED (__CET__ & 0x2)
#  define ZEND_FIBER_SHADOW_STACK SHSTK_ENABLED
# else
#  define _CET_ENDBR
# endif
.file "make_x86_64_sysv_elf_gas.S"
.text
.globl make_fcontext
.type make_fcontext,@function
.align 16
make_fcontext:
    _CET_ENDBR
    /* first arg of make_fcontext() == top of context-stack */
    movq  %rdi, %rax

    /* shift address in RAX to lower 16 byte boundary */
    andq  $-16, %rax

    /* reserve space for context-data on context-stack */
    /* on context-function entry: (RSP -0x8) % 16 == 0 */
    leaq  -0x40(%rax), %rax

    /* third arg of make_fcontext() == address of context-function */
    /* stored in RBX */
    movq  %rdx, 0x28(%rax)

    /* save MMX control- and status-word */
    stmxcsr  (%rax)
    /* save x87 control-word */
    fnstcw   0x4(%rax)

    /* compute abs address of label trampoline */
    leaq  trampoline(%rip), %rcx
    /* save address of trampoline as return-address for context-function */
    /* will be entered after calling jump_fcontext() first time */
    movq  %rcx, 0x38(%rax)

    /* compute abs address of label finish */
    leaq  finish(%rip), %rcx
    /* save address of finish as return-address for context-function */
    /* will be entered after context-function returns */
    movq  %rcx, 0x30(%rax)

#if ZEND_FIBER_SHADOW_STACK
    /* step1 allocate new shadow stack via syscall */
    /* TODO: save rax in r8(maybe a better way) before syscall */
    movq  %rax, %r8
    /* second arg of make_fcontext() == new stack size */
    /* TODO: shift right 5bits, then get the size of new shadow stack,
    store in RSI as the third arg for syscall */
	movq  $4096, %rax
    movq  %rax, %rsi

	/* the forth arg for syscall == shadow stack set token */
    movq  $0x1, %rax
    movq  %rax, %rdx
    /* the second arg for syscall*/
    movq  $0x0, %rdi

    /* store syscall number in rax, 0x1c3=451, 
    which is the syscall number for map shadow stack*/
	movq  $0x1c3, %rax
    /* The base address of new shadow stack should be return in rax */
	syscall
	/* TODO: Get the top of new shadow stack.*/
    addq  $4096, %rax
    movq  %rax, %r9
    /* restore rax because need to use r8 later */
    movq  %r8, %rax

    /* Populate the shadow stack and normal stack */
    /* get original SSP */
    rdsspq  %r8
    /* restore new shadow stack */
    rstorssp  -0x8(%r9)
    /* save the restore token on the original shadow stack */
    saveprevssp
    /* push the address of "jmp trampoline" to the new shadow stack */
    /* as well as the stack */
    call  1f
    jmp  trampoline
1:
    /* save address of "jmp trampoline" as return-address */
    /* for context-function */
    pop 0x38(%rax)
    /* Get the new SSP. */
    rdsspq  %r9
    /* restore original shadow stack */
    rstorssp  -0x8(%r8)
    /* save the restore token on the new shadow stack.  */
    saveprevssp

    /* reserve space for the new SSP */
    leaq  -0x8(%rax), %rax
    /* save the new SSP to this fcontext */
    movq  %r9, (%rax)
#endif

    ret /* return pointer to context-data */

trampoline:
    /* store return address on stack */
    /* fix stack alignment */
    _CET_ENDBR
#if ZEND_FIBER_SHADOW_STACK
    /* save address of "jmp *%rbp" as return-address */
    /* on stack and shadow stack */
    call  2f
    jmp  *%rbp
2:
#else
    push %rbp
#endif
    /* jump to context-function */
    jmp *%rbx

finish:
    _CET_ENDBR
    /* exit code is zero */
    xorq  %rdi, %rdi
    /* exit application */
    call  _exit@PLT
    hlt
.size make_fcontext,.-make_fcontext

/* Mark that we don't need executable stack. */
.section .note.GNU-stack,"",%progbits
