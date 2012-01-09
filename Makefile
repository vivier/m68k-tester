#
#  Makefile - M68K emulator tester
#
#  m68k-tester (C) 2007 Gwenole Beauchesne
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

# The following macros shall be defined
#  EMULATOR		name of the emulator (BasiliskII, Aranym, {,E-}UAE, QEMU)
#  EMULATOR_PATH	path to the emulator (actually, emulator headers)
#  MEMORY		memory addressing mode to use (real, direct, banks)

-include config.mak

ifeq ($(SRC_PATH),)
SRC_PATH = .
endif
ifeq ($(OBJ_DIR),)
OBJ_DIR = obj
endif

PACKAGE := m68k-tester
VERSION := 1.0
SVNDATE := $(shell [ -d .svn ] && LC_ALL=C TZ=GMT svn info | sed -n '/^Last Changed Date:.*\([0-9]\{4\}\)-\([01][0-9]\)-\([0-3][0-9]\).*/s//\1\2\3/p')
VERSION_SUFFIX := -$(SVNDATE)

CXX = g++
CXXFLAGS = -O2
CPPFLAGS = -DHAVE_CONFIG_H

# Define to yes if your emulator supports and is built with a JIT compiler
# NOTE: This is only useful if the emulator does not default to JIT mode
USE_JIT = no

# Select emulation core to use
#EMULATOR = BasiliskII
#EMULATOR = Aranym
#EMULATOR = UAE
#EMULATOR = E-UAE
EMULATOR = QEMU
EMULATOR_PATH = ../qemu-m68k/build-linux-user
ifeq ($(EMULATOR),)
EMULATOR = dummy
endif
CPPFLAGS += -I$(SRC_PATH)/src -I$(OBJ_DIR)
CPPFLAGS += -I$(EMULATOR_PATH) -I$(EMULATOR_PATH)/include -I$(EMULATOR_PATH)/../target-m68k -I$(EMULATOR_PATH)/..

# Dummy (only useful for pure results file conversion mode)
ifeq ($(EMULATOR), dummy)
GLUE_SRCS = m68k-tester-dummy.cpp
CPPFLAGS += -DEMU_DUMMY
endif

# Basilisk II
ifeq ($(EMULATOR), BasiliskII)
GLUE_SRCS = m68k-tester-uae.cpp
CPPFLAGS += -DEMU_BASILISK
# --enable-jit-compiler (default: no)
ifeq ($(USE_JIT), yes)
CPPFLAGS += -DUSE_JIT -DUSE_JIT_FPU
endif
# --enable-jit-debug (default: no)
CPPFLAGS += -DJIT_DEBUG
endif

# ARAnyM
ifeq ($(EMULATOR), Aranym)
GLUE_SRCS = m68k-tester-uae.cpp
GLUE_INCS = hardware.h SDL.h SDL_keyboard.h
CPPFLAGS += -I$(EMULATOR_PATH)/../include
CPPFLAGS += -DEMU_ARANYM
# --enable-jit-compiler (default: no)
ifeq ($(USE_JIT), yes)
CPPFLAGS += -DUSE_JIT -DUSE_JIT_FPU
endif
# --enable-realstop (default: yes)
CPPFLAGS += -DENABLE_EXCLUSIVE_SPCFLAGS
endif

# E-UAE
ifeq ($(EMULATOR), E-UAE)
override EMULATOR = UAE
CPPFLAGS += -DEMU_EUAE
CPPFLAGS += -DFPUEMU
CPPFLAGS += -DCPUEMU_0
# --enable-compatible-cpu (default: yes)
CPPFLAGS += -DCPUEMU_5
# --enable-cycle-exact-cpu (default: yes)
CPPFLAGS += -DCPUEMU_6
# --enable-jit (default: yes on x86)
ifeq ($(USE_JIT), yes)
CPPFLAGS += -DJIT
endif
# --enable-autoconfig (default: auto)
CPPFLAGS += -DAUTOCONFIG
# --enable-enforcer (default: auto, depends-on: autoconfig)
CPPFLAGS += -DENFORCER
# --enable-debugger (default: yes, because of configure bug)
CPPFLAGS += -DDEBUGGER
# --enable-aga (default: yes)
CPPFLAGS += -DAGA
# --enable-action-replay (default: yes)
CPPFLAGS += -DACTION_REPLAY
# --enable-state-saving (default: yes, because of configure bug)
CPPFLAGS += -DSAVESTATE
endif

# UAE
ifeq ($(EMULATOR), UAE)
GLUE_SRCS = m68k-tester-uae.cpp
CPPFLAGS += -DEMU_UAE
endif

# QEMU
ifeq ($(EMULATOR), QEMU)
GLUE_SRCS = m68k-tester-qemu.cpp
GLUE_INCS = softfloat.h qemu-types.h
CPPFLAGS += -I$(EMULATOR_PATH)/target-m68k
CPPFLAGS += -I$(EMULATOR_PATH)/m68k-linux-user
CPPFLAGS += -DEMU_QEMU
CPPFLAGS += -DVM_DEFAULT_ACCESSORS
CXXFLAGS += $(shell pkg-config --cflags gthread-2.0)
LIBS = $(shell pkg-config --libs gthread-2.0)
endif

# Memory addressing mode
# --enable-addressing=real
MEMORY = real
# --enable-addressing=direct
#MEMORY = direct
# --enable-addressing=banks (default)
#MEMORY = banks
# --enable-addressing=fixed
#MEMORY = fixed
# --enable-natmem
#MEMORY = natmem
ifeq ($(MEMORY), real)
CPPFLAGS += -DREAL_ADDRESSING
endif
ifeq ($(MEMORY), direct)
CPPFLAGS += -DDIRECT_ADDRESSING
endif
ifeq ($(MEMORY), fixed)
CPPFLAGS += -DFIXED_ADDRESSING -DFMEMORY=0x51000000
endif
ifeq ($(MEMORY), natmem)
CPPFLAGS += -DNATMEM_OFFSET=0x50000000
endif

# cxmon debugger
#USE_MON = yes
ifeq ($(USE_MON), yes)
ifneq ($(MON_PATH),)
CPPFLAGS += -I$(MON_PATH)/src -I$(MON_PATH)/src/disass
endif
CPPFLAGS += -DENABLE_MON
LIBS += -lreadline
endif

ifeq ($(EMULATOR), QEMU)
GLUE_LIBS	= libqemu.a
GEN_LIBS	= $(GLUE_LIBS:%.a=$(SRC_PATH)/obj/%.a)
GEN_INCS	= $(GLUE_INCS:%.h=$(OBJ_DIR)/%.h)
else
ifneq ($(EMULATOR), dummy)
GLUE_LIBS	= libemu68k.a
GEN_LIBS	= $(GLUE_LIBS:%.a=$(SRC_PATH)/libs/%.a)
GEN_INCS	= $(GLUE_INCS:%.h=$(OBJ_DIR)/%.h)
endif
endif

RAW_SRCS	= vm_alloc.cpp m68k-tester.cpp $(GLUE_SRCS)
SRCS		= $(RAW_SRCS:%=$(SRC_PATH)/src/%)
OBJS		= $(RAW_SRCS:%.cpp=$(OBJ_DIR)/%.o)
PROGS		= m68k-tester

archivedir	= files/
SRCARCHIVE	= $(PACKAGE)-$(VERSION)$(VERSION_SUFFIX).tar
FILES		= Makefile
FILES		+= README NEWS TODO COPYING ChangeLog
FILES		+= $(wildcard src/*.h)
FILES		+= $(wildcard src/*.cpp)
FILES		+= $(wildcard patches/*.patch)

all: $(PROGS)

$(OBJ_DIR)::
	@[ -d $(OBJ_DIR) ] || mkdir $(OBJ_DIR) > /dev/null 2>&1

define SRCS_LIST_TO_OBJS
	$(addprefix $(OBJ_DIR)/, $(addsuffix .o, $(foreach file, $(SRCS), \
	$(basename $(notdir $(file))))))
endef
OBJS = $(SRCS_LIST_TO_OBJS)

clean:
	rm -f $(PROGS) $(OBJS) $(GEN_INCS)

distclean: clean
	rm -rf $(OBJ_DIR)
	rm -f core* *.core *~ *.bak
	rm -f $(SRC_PATH)/src/*~ $(SRC_PATH)/src/*.bak

$(archivedir)::
	[ -d $(archivedir) ] || mkdir $(archivedir) > /dev/null 2>&1

tarball:
	$(MAKE) -C $(SRC_PATH) do_tarball
do_tarball: $(archivedir) $(archivedir)$(SRCARCHIVE).bz2

$(archivedir)$(SRCARCHIVE): $(archivedir) $(FILES)
	BUILDDIR=`mktemp -d /tmp/buildXXXXXXXX`						; \
	mkdir -p $$BUILDDIR/$(PACKAGE)-$(VERSION)					; \
	(cd $(SRC_PATH) && tar c $(FILES)) | tar x -C $$BUILDDIR/$(PACKAGE)-$(VERSION)	; \
	(cd $$BUILDDIR && tar cvf $(SRCARCHIVE) $(PACKAGE)-$(VERSION))			; \
	mv -f $$BUILDDIR/$(SRCARCHIVE) $(archivedir)					; \
	rm -rf $$BUILDDIR
$(archivedir)$(SRCARCHIVE).bz2: $(archivedir)$(SRCARCHIVE)
	bzip2 -9vf $(archivedir)$(SRCARCHIVE)

changelog: ../common/authors.xml
	svn_prefix=`LC_ALL=C svn info .|sed -n '/^URL *: .*\/svn\/\(.*\)$$/s//\1\//p'`; \
	svn2cl --strip-prefix=$$svn_prefix --authors=../common/authors.xml || :
changelog.commit:
	svn commit -m "Generated by svn2cl." ChangeLog

m68k-tester: $(OBJ_DIR) $(OBJS) $(GEN_LIBS)
	$(CXX) $(CXXFLAGS) -o $@ $(OBJS) $(GEN_LIBS) $(LIBS)

ifeq ($(EMULATOR), QEMU)
QEMU_LIB_FILES = $(addprefix $(EMULATOR_PATH)/m68k-linux-user/, main.o syscall.o strace.o mmap.o signal.o thunk.o elfload.o linuxload.o uaccess.o gdbstub.o cpu-uname.o flatload.o ../libuser/envlist.o ../libuser/path.o ../libuser/tcg-runtime.o ../libuser/host-utils.o ../libuser/cutils.o ../libuser/cache-utils.o ../libdis-user/i386-dis.o ../libdis-user/m68k-dis.o exec.o translate-all.o cpu-exec.o translate.o tcg/tcg.o tcg/optimize.o fpu/softfloat.o op_helper.o helper.o disas.o gdbstub-xml.o m68k-sim.o m68k-semi.o user-exec.o)

$(GEN_LIBS): $(QEMU_LIB_FILES)
	ar r $@ $^
else
$(GEN_LIBS):
	@echo "Emulator static library is missing" && exit 1
endif

$(OBJ_DIR)/%.o: $(SRC_PATH)/src/%.cpp $(GEN_INCS)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ -c $<

$(GEN_INCS): %.h:
	def=`echo "$(notdir $@)" | tr '.[:lower:]-' '_[:upper:]_'`	; \
	echo "#ifndef $$def" > $@					; \
	echo "#define $$def" >> $@					; \
	echo "#endif /* $$def */" >> $@
