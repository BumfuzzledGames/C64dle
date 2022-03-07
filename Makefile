CFLAGS=-Wall -Werror -std=c99
X64 ?= x64sc
C64DBG ?= c64debugger

all: wordle.d64

makedict: makedict.c
	$(CC) $(CFLAGS) $< -o $@

dict.prg: makedict 10000_5_letter_words_no_newlines.txt
	./makedict 10000_5_letter_words_no_newlines.txt dict.prg

wordle.prg: wordle.asm
	kickass -vicesymbols -debugdump wordle.asm wordle.prg

wordle.d64: wordle.prg dict.prg
	c1541 -format wordle,0 d64 wordle.d64
	c1541 -attach wordle.d64 -write wordle.prg wordle
	c1541 -attach wordle.d64 -write dict.prg dictionary

.phony: clean
clean:
	rm -f dict.bin wordle.prg wordle.d64

.phony: run
run: wordle.d64
	$(X64) -autostartprgmode 1 wordle.d64

.phony: debug
debug: wordle.d64
	$(C64DBG) -d64 wordle.d64
