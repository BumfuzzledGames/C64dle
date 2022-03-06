// Process dict.txt into dict.asm
#include <stdio.h>
#include <ctype.h>
#define WORDS_PER_LINE 8

char *next_word(FILE *f) {
  static char word[6] = {0};
  int chars;

  if(fscanf(f, "%5s%n\n", word, &chars) != 1 || chars != 5) {
    return NULL;
  } else {
    for(int i = 0; i < 5; i++) {
      word[i] = toupper(word[i]);
    }
    return word;
  }
}

void next_group(char *g) {
  g[1]++;
  if(g[1] > 'Z') {
    g[1] = 'A';
    g[0]++;
  }
}

int word_group(char *w) {
  return (w[0]-'A')*26+(w[1]-'A');
}

int pack_word(char *w) {
  return (w[0]-'A') | ((w[1]-'A') << 5) | ((w[2]-'A') << 10);
}

int main() {
  FILE *input = fopen("dict.txt", "r");
  if(input == NULL) {
    fprintf(stderr, "Could not open dict.txt\n");
    return -1;
  }

  FILE *dict_asm = fopen("dict.asm", "w+");
  if(dict_asm == NULL) {
    fprintf(stderr, "Could not open dict.asm for writing\n");
    return -1;
  }

  int table[26*26] = {0};
  int num_words = 0;
  int words_on_line = 0;
  
  fprintf(dict_asm, "dict:\n");
  for(char *w = next_word(input); w; w = next_word(input)) {
    if(words_on_line == 0) {
      fprintf(dict_asm, "   .word ");
    } else {
      fprintf(dict_asm, ",");
    }
    
    fprintf(dict_asm, "$%04x", pack_word(w+2));

    table[word_group(w)]++;
    if(table[word_group(w)] > 255) {
      fprintf(stderr, "ERROR!!! The group for %s has too many elements: %d\n", w, table[word_group(w)]);
    }
    
    num_words++;
    words_on_line++;
    if(words_on_line == WORDS_PER_LINE) {
      fprintf(dict_asm, "\n");
      words_on_line = 0;
    }
  }
  if(words_on_line != WORDS_PER_LINE) {
    fprintf(dict_asm, "\n");
  }
  fprintf(dict_asm, "\n");

  fprintf(dict_asm, "table:\n");

  char group[2] = "AA";
  for(int i = 0; i < 26*26; i++) {
    fprintf(dict_asm, "table_%s: .byte %d\n", group, table[word_group(group)]);
    group[1]++;
    if(group[1] > 'Z') {
      group[1] = 'A';
      group[0]++;
    }
  }
  fprintf(dict_asm, "\n");

  return 0;
}
