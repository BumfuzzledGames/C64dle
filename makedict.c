// Process dict.txt into dict.asm
#include <stdio.h>
#include <ctype.h>
#include <stdint.h>
#include <stdlib.h>

// Read the next word from file, returns static buffer
char *next_word(FILE *f) {
  static char word[6] = {0};

  if(fread(word, 1, 5, f) != 5) {
    return NULL;
  }
  for(int i = 0; i < 5; i++) {
    if(!isupper(word[i])) {
      fprintf(stderr, "Invalid word found\n");
      return NULL;
    }
  }
  
  return word;
}

// Pack word with uint32_t using 5-bit encoding
uint32_t pack_word(char *w) {
  return
    ((w[0]-'A')&0x1F) << 27 |
    ((w[1]-'A')&0x1F) << 22 |
    ((w[2]-'A')&0x1F) << 17 |
    ((w[3]-'A')&0x1F) << 12 |
    ((w[4]-'A')&0x1F) << 7;
}

// Open a file or die trying
FILE *open_file(const char *filename, const char *mode) {
  FILE *f = fopen(filename, mode);
  if(f == NULL) {
    fprintf(stderr, "Error: Could not open %s\n", filename);
    exit(EXIT_FAILURE);
  }
  return f;
}

int main(int argc, char *argv[]) {
  if(argc != 3) {
    fprintf(stderr, "Usage: %s dict.txt dict.bin\n", argv[0]);
    return EXIT_FAILURE;
  }
  FILE *input = open_file(argv[1], "rb");
  FILE *output = open_file(argv[2], "wb+");

  // Words
  for(char *word = next_word(input); word != NULL; word = next_word(input)) {
    uint32_t packed_word = pack_word(word);
    fputc((packed_word & 0xFF000000) >> 24, output);
    fputc((packed_word & 0x00FF0000) >> 16, output);
    fputc((packed_word & 0x0000FF00) >> 8, output);
    fputc((packed_word & 0x000000FF), output);
  }
  // Terminator
  for(int i = 0; i < 4; i++) {
    fputc(0xFF, output);
  }
  
  return 0;
}
