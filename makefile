DMD ?= dmd
ARCHFLAG ?= -m64
DFLAGS = $(ARCHFLAG) -w -debug -gc -unittest

LIBD_ROOT = .

include makefile.common

clean:
	@rm -rf obj lib

.PHONY: clean
