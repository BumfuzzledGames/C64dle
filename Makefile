CFLAGS  =-Wall -Werror -std=c99
CC      ?= gcc
KICKASS ?= kickass
X64     ?= x64sc
C64DBG  ?= c64debugger
C1541   ?= c1541

all: wordle.prg

makedict: makedict.c
	$(CC) $(CFLAGS) $< -o $@

wordlist.txt: 5_letter_words_by_frequency.txt
	head -10000 5_letter_words_by_frequency.txt | tr -d \\n | tr [:lower:] [:upper:] >wordlist.txt 

dict.prg: makedict wordlist.txt
	./makedict wordlist.txt dict.prg

wordle.prg: wordle.asm dict.prg
	$(KICKASS) -vicesymbols -debugdump wordle.asm wordle.prg

wordle.d64: wordle.prg
	$(C1541) -format wordle,0 d64 wordle.d64
	$(C1541) -attach wordle.d64 -write wordle.prg wordle

.phony: clean
clean:
	rm -f dict.bin wordle.prg dict.prg wordle.d64 wordlist.txt

.phony: run
run: wordle.d64
	$(X64) -autostartprgmode 1 wordle.prg

.phony: debug
debug: wordle.d64
	$(C64DBG) wordle.prg
