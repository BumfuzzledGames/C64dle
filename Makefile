CFLAGS  =-Wall -Werror -std=c99
CC      ?= gcc
KICKASS ?= kickass
X64     ?= x64sc
C64DBG  ?= c64debugger
C1541   ?= c1541

all: wordle.prg

makedict: makedict.c
	$(CC) $(CFLAGS) $< -o $@

dict.prg: makedict 10000_5_letter_words_no_newlines.txt
	./makedict 10000_5_letter_words_no_newlines.txt dict.prg

wordle.prg: wordle.asm dict.prg
	$(KICKASS) -vicesymbols -debugdump wordle.asm wordle.prg

wordle.d64: wordle.prg
	$(C1541) -format wordle,0 d64 wordle.d64
	$(C1541) -attach wordle.d64 -write wordle.prg wordle

.phony: clean
clean:
	rm -f dict.bin wordle.prg dict.prg wordle.d64

.phony: run
run: wordle.d64
	$(X64) -autostartprgmode 1 wordle.prg

.phony: debug
debug: wordle.d64
	$(C64DBG) wordle.prg