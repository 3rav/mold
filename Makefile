CC = clang
CXX = clang++

MIMALLOC_LIB = mimalloc/out/release/libmimalloc.a
GIT_HASH ?= $(shell [ -d .git ] && git rev-parse HEAD)

CPPFLAGS = -g -Imimalloc/include -pthread -std=c++20 \
           -Wno-deprecated-volatile \
           -DMOLD_VERSION=\"0.9.1\" \
           -DGIT_HASH=\"$(GIT_HASH)\" \
	   $(EXTRA_CPPFLAGS)
LDFLAGS += $(EXTRA_LDFLAGS)
LIBS = -Wl,-as-needed -lcrypto -pthread -ltbb -lz -lxxhash -ldl
OBJS = main.o object_file.o input_sections.o output_chunks.o \
       mapfile.o perf.o linker_script.o archive_file.o output_file.o \
       subprocess.o gc_sections.o icf.o symbols.o cmdline.o filepath.o \
       passes.o tar.o compress.o memory_mapped_file.o relocatable.o \
       arch_x86_64.o arch_i386.o

PREFIX ?= /usr
DEBUG ?= 0
LTO ?= 0
ASAN ?= 0
TSAN ?= 0

ifeq ($(DEBUG), 1)
  CPPFLAGS += -O0
else
  CPPFLAGS += -O2
endif

ifeq ($(LTO), 1)
  CPPFLAGS += -flto -O3
  LDFLAGS  += -flto
endif

ifeq ($(ASAN), 1)
  CPPFLAGS += -fsanitize=address
  LDFLAGS  += -fsanitize=address
else
  # By default, we want to use mimalloc as a memory allocator.
  # Since replacing the standard malloc is not compatible with ASAN,
  # we do that only when ASAN is not enabled.
  ifndef SYSTEM_MIMALLOC
    LIBS += -Wl,-whole-archive $(MIMALLOC_LIB) -Wl,-no-whole-archive
  else
    LIBS += -lmimalloc
  endif
endif

ifeq ($(TSAN), 1)
  CPPFLAGS += -fsanitize=thread
  LDFLAGS  += -fsanitize=thread
endif

all: mold mold-wrapper.so

ifdef SYSTEM_MIMALLOC
  undefine MIMALLOC_LIB
endif

mold: $(OBJS) $(MIMALLOC_LIB)
	$(CXX) $(CXXFLAGS) $(OBJS) -o $@ $(LDFLAGS) $(LIBS)

mold-wrapper.so: mold-wrapper.c Makefile
	$(CC) -fPIC -shared -o $@ $< -ldl

$(OBJS): mold.h elf.h Makefile

$(MIMALLOC_LIB):
	mkdir -p mimalloc/out/release
	(cd mimalloc/out/release; CFLAGS=-DMI_USE_ENVIRON=0 cmake ../..)
	$(MAKE) -C mimalloc/out/release

test tests check: all
	 $(MAKE) -C test --output-sync --no-print-directory

install: all
	install -m 755 mold $(DESTDIR)$(PREFIX)/bin
	strip $(PREFIX)/bin/mold

	install -m 755 -d $(DESTDIR)$(PREFIX)/lib/mold
	install -m 644 mold-wrapper.so $(DESTDIR)$(PREFIX)/lib/mold
	strip $(DESTDIR)$(PREFIX)/lib/mold/mold-wrapper.so

	install -m 755 -d $(DESTDIR)$(PREFIX)/share/man/man1
	install -m 644 docs/mold.1 $(DESTDIR)$(PREFIX)/share/man/man1
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/mold.1.gz
	gzip -9 $(DESTDIR)$(PREFIX)/share/man/man1/mold.1

uninstall:
	rm -rf $(DESTDIR)$(PREFIX)/bin/mold $(DESTDIR)$(PREFIX)/share/man/man1/mold.1.gz \
	       $(DESTDIR)$(PREFIX)/lib/mold

clean:
	rm -rf *.o *~ mold mold-wrapper.so test/tmp

.PHONY: all test tests check clean $(TESTS)
