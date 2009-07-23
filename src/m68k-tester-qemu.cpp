/*
 *  m68k-tester-qemu.cpp - M68K emulator tester, glue for QEMU-based cores
 *
 *  m68k-tester (C) 2007 Gwenole Beauchesne
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <malloc.h>

#include "sysdeps.h"
#include "vm_alloc.h"
#include "m68k-tester.h"

#define DEBUG 0
#include "debug.h"


/* <config-host.h> glue */
#if defined __LP64__
#define HOST_LONG_BITS 64
#endif
#if defined __linux__
#define HAVE_BYTESWAP_H 1
#endif

/* <config.h> glue */
#define TARGET_M68K 1
#define TARGET_WORDS_BIGENDIAN 1
#if 1
#define CONFIG_USER_ONLY 1
#define CONFIG_LINUX_USER 1
#endif
#define CONFIG_SOFTFLOAT 1

/* <softfloat.h> glue */
#if (defined(__i386__) || defined(__x86_64__)) && !defined(_BSD)
#define FLOATX80
#endif
typedef uint32 float32;
typedef uint64 float64;
typedef struct float_status {
    signed char float_detect_tininess;
    signed char float_rounding_mode;
    signed char float_exception_flags;
#ifdef FLOATX80
    signed char floatx80_rounding_precision;
#endif
} float_status;

#if defined(__x86_64__)
#define TARGET_PHYS_ADDR_BITS 64
#elif defined(__i386__)
#define TARGET_PHYS_ADDR_BITS 32
#endif

#if EMU_QEMU
extern "C" {
#define NEED_CPU_H
#include "cpu.h"
extern void tb_flush(CPUM68KState*);
extern void cpu_dump_state(CPUM68KState *env, FILE *f,
						   int (*cpu_fprintf)(FILE *f, const char *fmt, ...),
						   int flags);
}
#endif

unsigned long guest_base;

static int m68k_memory_init(void)
{
	if (vm_init() < 0)
		return -1;
	if (vm_acquire_fixed((void *)(uintptr)M68K_CODE_BASE, M68K_CODE_SIZE) < 0)
		return -1;
	return 0;
}

static void m68k_memory_exit(void)
{
	vm_release((void *)(uintptr)M68K_CODE_BASE, M68K_CODE_SIZE);
}

static CPUM68KState *m68k_cpu_init(void)
{
	char cpu_str[] = "m68000";
	cpu_str[4] = CPUType + '0';
	CPUM68KState *cpu = cpu_m68k_init(cpu_str);
	if (cpu == NULL)
		return NULL;

	return cpu;
}

static void m68k_cpu_exit(CPUM68KState *cpu)
{
	cpu_m68k_close(cpu);
}

static void m68k_execute(CPUM68KState *cpu)
{
	for (;;) {
		int trapnr = cpu_m68k_exec(cpu);
		switch (trapnr) {
		case EXCP_EXEC_RETURN:
			// special opcode, exit from m68k execution loop
			return;
		default:
			fprintf(stderr, "qemu: unhandled CPU exception 0x%x - aborting\n",
					trapnr);
			cpu_dump_state(cpu, stderr, fprintf, 0);
			abort();
		}
	}
}


#define M68K_STATE ((CPUM68KState *)opaque)

m68k_cpu::m68k_cpu()
{
	m68k_memory_init();
	cpu_exec_init_all(0);
	opaque = m68k_cpu_init();
	assert(opaque != NULL);
}

m68k_cpu::~m68k_cpu()
{
	m68k_cpu_exit(M68K_STATE);
	m68k_memory_exit();
}

uint32 m68k_cpu::get_pc() const
{
	return M68K_STATE->pc;
}

void m68k_cpu::set_pc(uint32 pc)
{
	M68K_STATE->pc = pc;
}

uint32 m68k_cpu::get_ccr() const
{
	return M68K_STATE->sr & M68K_CCR_BITS;
}

void m68k_cpu::set_ccr(uint32 ccr)
{
	M68K_STATE->sr = (M68K_STATE->sr & ~M68K_CCR_BITS) | (ccr & M68K_CCR_BITS);
}

uint32 m68k_cpu::get_dreg(int r) const
{
	return M68K_STATE->dregs[r];
}

void m68k_cpu::set_dreg(int r, uint32 v)
{
	M68K_STATE->dregs[r] = v;
}

uint32 m68k_cpu::get_areg(int r) const
{
	return M68K_STATE->aregs[r];
}

void m68k_cpu::set_areg(int r, uint32 v)
{
	M68K_STATE->aregs[r] = v;
}

void m68k_cpu::reset(void)
{
}

void m68k_cpu::reset_jit(void)
{
	tb_flush(M68K_STATE);
}

void m68k_cpu::execute(uint32 pc)
{
	D(bug("* execute code at %08x\n", pc));
	set_pc(pc);
	m68k_execute(M68K_STATE);
}

extern "C" {

int singlestep;
unsigned long last_brk;

void pstrcpy(char *buf, int buf_size, const char *str)
{
    int c;
    char *q = buf;

    if (buf_size <= 0)
        return;

    for(;;) {
        c = *str++;
        if (c == 0 || q >= buf + buf_size - 1)
            break;
        *q++ = c;
    }
    *q = '\0';
}

void qemu_free(void *ptr)
{
    free(ptr);
}

void *qemu_malloc(size_t size)
{
    return malloc(size);
}

void *qemu_mallocz(size_t size)
{
    void *ptr;
    ptr = qemu_malloc(size);
    if (!ptr)
        return NULL;
    memset(ptr, 0, size);
    return ptr;
}

void mmap_lock(void )
{
    return;
}

void mmap_unlock(void)
{
    return;
}

void cpu_list_lock(void)
{
}

void *qemu_vmalloc(size_t size)
{
    return memalign(4096, size);
}

void cpu_list_unlock(void)
{
}

typedef int (*gdb_reg_cb)(CPUState *env, uint8_t *buf, int reg);

void gdb_register_coprocessor(CPUState * env,
                             gdb_reg_cb get_reg, gdb_reg_cb set_reg,
                             int num_regs, const char *xml, int g_pos)
{
}
}
