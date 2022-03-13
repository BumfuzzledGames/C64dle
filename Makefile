CFLAGS  =-Wall -Werror -std=c99
CC      ?= gcc
KICKASS ?= kickass
X64     ?= x64sc
C64DBG  ?= c64debugger
C1541   ?= c1541

all: c64dle.prg

makedict: makedict.c
	$(CC) $(CFLAGS) $< -o $@

dictns.txt: frequency.txt scrabble.txt
	grep -Fx -f scrabble.txt frequency.txt | \
		head -10000 | \
		tr -dc [:upper:] >dictns.txt

dict.bin: makedict dictns.txt
	./makedict dictns.txt dict.bin

c64dle.prg: c64dle.asm dict.bin gamescreen.asm kernal.inc macros.inc color.inc
	$(KICKASS) -vicesymbols -debugdump c64dle.asm c64dle.prg

c64dle.d64: c64dle.prg
	$(C1541) -format c64dle,0 d64 c64dle.d64
	$(C1541) -attach c64dle.d64 -write c64dle.prg c64dle

.phony: clean
clean:
	rm -f dict.bin c64dle.prg dict.prg c64dle.d64 dictns.txt

.phony: run
run: c64dle.prg
	$(X64) -autostartprgmode 1 c64dle.prg

.phony: debug
debug: c64dle.prg
	$(C64DBG) c64dle.prg
