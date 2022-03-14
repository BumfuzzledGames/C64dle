/* C64dle, by Bumfuzzled Games
 * A totally original word game not based on any other
 * work at all. No siree, totally my idea. Not Josh Wardle or
 * anyone else. Nope, nothing to see here, move along.
 *
 * But no, really, this is a Wordle clone.
 */

BasicUpstart2(start)
#import "kernal.inc"
#import "macros.inc"
#import "color.inc"

.const BACKGROUND_COLOR=COLORRAM_BLACK
.const BORDER_COLOR=COLORRAM_BLACK
            
.const MATCH_EXACT=COLORRAM_GREEN
.const MATCH_INEXACT=COLORRAM_YELLOW
.const MATCH_NONE=COLORRAM_DARK_GREY

.const GAME_PHASES=6
            
guessed_word:
   .text "WORDS"
   .fill 1,0
guessed_matches:          
   .fill 5,0
secret_word:    
   .fill 6,0
secret_word_matches:
   .fill 5,0

//screen stuff
word_offsets:                 //offset in screen of each word row
   .word scrpos(2,1)
   .word scrpos(2,5)
   .word scrpos(2,9)
   .word scrpos(2,13)
   .word scrpos(2,17)
   .word scrpos(2,21)
color_offsets:
   .word clrpos(2,1)
   .word clrpos(2,5)
   .word clrpos(2,9)
   .word clrpos(2,13)
   .word clrpos(2,17)
   .word clrpos(2,21)
keyboard_offsets:
   .word clrpos(20,11)          //A
   .word clrpos(29,13)          //B
   .word clrpos(25,13)          //C
   .word clrpos(24,11)          //D
   .word clrpos(23, 9)          //E
   .word clrpos(26,11)          //F
   .word clrpos(28,11)          //G
   .word clrpos(30,11)          //H
   .word clrpos(33, 9)          //I
   .word clrpos(32,11)          //J
   .word clrpos(34,11)          //K
   .word clrpos(36,11)          //L
   .word clrpos(33,13)          //M
   .word clrpos(31,13)          //N
   .word clrpos(35, 9)          //O
   .word clrpos(37, 9)          //P
   .word clrpos(19, 9)          //Q
   .word clrpos(25, 9)          //R
   .word clrpos(22,11)          //S
   .word clrpos(27, 9)          //T
   .word clrpos(31, 9)          //U
   .word clrpos(27,13)          //V
   .word clrpos(21, 9)          //W
   .word clrpos(23,13)          //X
   .word clrpos(29, 9)          //Y
   .word clrpos(21, 9)          //Z
.const MESSAGE_BOX_OFFSET=scrpos(21,17)
.const MESSAGE_BOX_LENGTH=15

phase:                          //current phase of the game
   .byte 0

//messages for the message box
.encoding "screencode_upper"
msg_prompt:                  
   .text "  PRESS ENTER  "
msg_checking:
   .text "  CHECKING...  "
msg_empty:
   .text "               "
msg_invalid:
   .text " INVALID  WORD "
msg_won:
   .text "    YOU WON!   "
msg_lost:
   .text " IT WAS XXXXX  "
.const MSG_LOST_WORD=msg_lost+8
.encoding "ascii"

buffer:
    .fill 6,0
.const buffer_len = *-buffer

start: {
   sei                        //disable BASIC ROM
   lda $1                     //TODO: don't do this if program
   and #%11111110             //doesn't overlap with BASIC
   sta $1
   cli


   lda #$ff                   //get the sid noise channel running
   sta $d40e
   sta $d40f
   lda #$80
   sta $d412

   lda #<screen_wordle
   sta $fb
   lda #>screen_wordle
   sta $fc
   jsr draw_screen
   DISPLAY(msg_prompt)
   jmp * 
!: jsr KERNAL_GETIN
   cmp #$0d
   bne !-
   lda $d41b   
               //get random number
   sta rand.x                 //seed PRNG
   jmp play

loop:
   lda #<screen_wordle
   sta $fb
   lda #>screen_wordle
   sta $fc
   DISPLAY(msg_prompt)
!: jsr KERNAL_GETIN
   cmp #$0d
   bne !-
play:
   DISPLAY(msg_empty)
   jsr play_game
!: jsr KERNAL_GETIN
   beq !-
   cmp #$0d
   bne !-
   jmp loop

done:      
   sei                        //enable BASIC ROM
   lda $1
   ora #%00000001
   sta $1
   cli

   rts
}


/* draw_screen  Draw a screen to screen
   Parameters
     $fb,$fc
       Address of screen to draw. This is in the
       format of:
         background_color   1 byte
         border_color       1 byte
         characters         1000 bytes
         colors             1000 bytes
   Returns  nothing
   Mangles  A,X,Y,$fb-$fe
*/
draw_screen: {
   ldy #0               //background and border color
   lda ($fb),y
   sta 53281
   iny
   lda ($fb),y
   sta 53280
   lda $fb              //skip color bytes
   clc
   adc #2
   sta $fb
   bcc !+
   inc $fc
!: lda #<1024           //copy to screen
   sta $fd
   lda #>1024
   sta $fe
   jsr copy
   lda #<$D800          //copy to color RAM
   sta $fd
   lda #>$D800
   sta $fe
   jsr copy
   rts

copy: {
   ldx #4               //copy 4 blocks of 250
loopx:
   ldy #0
loopy:
   lda ($fb),y
   sta ($fd),y
   iny
   cpy #250
   bne loopy
   lda $fb              //next 250 chunk on input
   clc
   adc #250
   sta $fb
   bcc !+
   inc $fc
!: lda $fd              //next 250 chunk on output
   clc
   adc #250
   sta $fd
   bcc !+
   inc $fe
!: dex                  //4 blocks
   bne loopx
   rts
}
}


//draw secret word at top of screen for debugging
debug_draw_secret_word: {
   pha                  //A
   txa                  //X
   pha

   ldx #4
!: lda secret_word,x
   sec
   sbc #64
   sta 1024,x
   dex
   bpl !-

   pla                  //X
   tax                 
   pla                  //A
   rts
}


//draw word of current phase
draw_word: {
   pha                  //A
   txa                  //X
   pha
   tya                  //Y
   pha

   lda phase            //current phase*2
   asl
   tax
   lda word_offsets,x
   clc                  //add 41 to offset
   adc #41
   sta _screen_offset
   lda word_offsets+1,x
   adc #0
   sta _screen_offset+1

   ldx #0
   ldy #0
loop:
   lda _input:guessed_word,x
   bne !+
   lda #' '
   jmp !++
!: sec                  //PETSCII to screen code
   sbc #64              //assumes only letters in word
!: sta _screen_offset:$1024,y
   clc
   tya
   adc #3
   tay
   inx
   cpx #5
   bne loop

done:   
   pla                  //Y
   tay          
   pla                  //X
   tax                 
   pla                  //A
   rts
}


.macro DISPLAY(string) {
   m16 #string:display_message._string
   jsr display_message
}
display_message: {
   ldx #MESSAGE_BOX_LENGTH-1
!: lda _string:$ffff,x
   clc                  //reverse
   adc #128
   sta MESSAGE_BOX_OFFSET,x
   dex
   bpl !-
   rts
}


clear_message: {
   ldx #MESSAGE_BOX_LENGTH-1
   lda #$20+128
!: sta MESSAGE_BOX_OFFSET,x
   dex
   bpl !-
   rts
}


//phase*4*40+41 + letter*4
get_letter_bubble_offset: {
   lda #41                    //41
   sta _output
   lda #0
   sta _output+1
   ldx _phase:#1
!: clc
   lda _output
   adc #40*4                  //+y*40*4
   sta _output
   bcc !+
   inc _output+1
!: dex
   bpl !--
   lda _letter:#1             //x*4
   asl
   asl
   clc
   adc _output
   sta _output
   bcc !+
   inc _output+1
!: rts
_output:                      
   .word 0
}


play_game:{
   //jsr draw_wordle_screen
   lda #0                     //reset phase
   sta phase
   
   m16 #secret_word:decode_word._output
   jsr random_word            //pick secret word

   ldx #4
   lda #0
!: sta guessed_word,x
   dex
   bpl !-

   //jsr debug_draw_secret_word
main_loop:
   m16 #draw_word:read_string._chrout
   mov #0:read_string._idx
   mov #5:read_string._buffer_len
   m16 #guessed_word:read_string._buffer
              
get_guess: {         
   jsr read_string

   m16 #guessed_word:is_valid._input
   DISPLAY(msg_checking)
   jsr is_valid
   bcc clear_matches
   //TODO Make a sound or something
   DISPLAY(msg_invalid)
   mov #5:read_string._idx
   jmp get_guess
}

clear_matches: {
   DISPLAY(msg_empty)
   ldx #4
loop:              
   lda #MATCH_NONE
   sta guessed_matches,x
   lda #0
   sta secret_word_matches,x
   dex
   bpl loop
}
   
find_exact_matches: {
   ldx #4                     //idx
loop:                   
   lda guessed_word,x
   cmp secret_word,x
   bne !+
   lda #MATCH_EXACT
   sta guessed_matches,x
   lda #1
   sta secret_word_matches,x
!: dex
   bpl loop
}
   
find_inexact_matches: {
   ldx #4                     //idx into guessed_word
loop:               
   lda guessed_matches,x
   cmp #MATCH_EXACT           //skip already matched letters
   beq next_guess_letter
   ldy #4                     //idx into secret_word
secret_loop:        
   lda secret_word_matches,y  //skip already matched letters
   bne next_secret_letter
   lda guessed_word,x
   cmp secret_word,y
   bne next_secret_letter
   lda #MATCH_INEXACT         //found an inexact match
   sta guessed_matches,x
   lda #1
   sta secret_word_matches,y
   jmp next_guess_letter
next_secret_letter: 
   dey
   bpl secret_loop
next_guess_letter:        
   dex
   bpl loop
}
   
//print word with colors
color_guess: {
   lda phase            //phase*2
   asl
   tax
   lda color_offsets,x
   sta row_offset
   lda color_offsets+1,x
   adc #0
   sta row_offset+1
   
   ldy #2               //3 screen rows
row:
   ldx #0               //5 letters
letter:
   tya                  //preserve y
   pha
   lda guessed_matches,x
   ldy #2               //3 columns
!: sta row_offset:$1024,y
   dey
   bpl !-
   pla                  //restore y
   tay
   lda row_offset       //next 3 columns
   clc
   adc #3
   sta row_offset
   lda row_offset+1
   adc #0
   sta row_offset+1
   inx
   cpx #5
   bne letter
   lda row_offset       //go to next row
   clc
   adc #25
   sta row_offset
   lda row_offset+1
   adc #0
   sta row_offset+1
   dey
   bpl row
}

color_keyboard: {
   ldx #4               //5 letters
loop:
   //store keyboard offset in $fd
   lda guessed_word,x
   sec
   sbc #'A'
   asl
   tay
   lsr
   lda keyboard_offsets,y
   sta $fd
   lda keyboard_offsets+1,y
   sta $fe
   ldy #0
   lda #MATCH_EXACT     //don't overwrite EXACT
   cmp ($fd),y
   beq loop_end
   lda #MATCH_INEXACT   //overwrite INEXACT with EXACT
   cmp ($fd),y
   bne !+
   lda guessed_matches,x
   cmp #MATCH_EXACT
   bne !+
   jmp store_color
!: lda guessed_matches,x
store_color:            
   sta ($fd),y
loop_end:               
   dex
   bpl loop
}
   
did_player_win: {
   ldx #4
   ldy #0
loop:
   lda guessed_matches,x
   cmp #MATCH_EXACT
   bne !+
   iny
!: dex
   bpl loop
   cpy #5
   bne no_win
   DISPLAY(msg_won)
   rts
no_win:
}

   //loop
   inc phase
   lda phase
   cmp #6
   beq lose
   
   ldx #4               //clear guessed word
   lda #0
!: sta guessed_word,x
   dex
   bpl !-

   mov #0:read_string._idx
   jmp main_loop

lose:
   ldx #4               //5 letters
!: lda secret_word,x
   sec
   sbc #64
   sta MSG_LOST_WORD,x
   dex
   bpl !-
   DISPLAY(msg_lost)
   rts
}


/* print  Prints a nul-terminated string
   Parameters
      _string
        Address of string to print
      _printer
        Routine to print a character. Defaults
        to KERNAL_CHROUT
   Returns  nothing
   Mangles A,X
*/
print: {
   ldx #0
!: lda _string:$ffff,x
   beq !+
   jsr _printer:KERNAL_CHROUT
   inx
   jmp !-
!: rts
}
.macro PRINT(string) {
   m16 #string:print._string
   jsr print
}


/* random_word  Get random word
   Parameters
     decode_word._output
       Address to store decoded word
     _max_hi and _max_lo
       High and low byte of highest index of word. Set to
       higher numbers for less common words.
   Returns  Random word in decode in decode_word._output
   Mangles  A,X,Y
*/
random_word: {
   lda _num_words_lo:#<1000   //choose a random number
   sta rand16_max._max_lo
   lda _num_words_hi:#>1000
   sta rand16_max._max_hi
   m16 #rand16_max._max_mode_max:rand16_max._max_mode
   jsr rand16_max

   lda rand16_max._output     //random number into dict_ptr
   sta dict_ptr
   lda rand16_max._output+1
   sta dict_ptr+1

   clc                        //dict_ptr *= 4
   rol dict_ptr
   rol dict_ptr+1
   clc
   rol dict_ptr
   rol dict_ptr+1

   clc                        //dict_ptr += dict
   lda dict_ptr
   adc #<dict
   sta dict_ptr
   lda dict_ptr+1
   adc #>dict
   sta dict_ptr+1

   ldx #3                     //load 4 bytes into decode_word input
!: lda dict_ptr:dict,x
   sta decode_word._input,x
   dex
   bpl !-
   jmp decode_word            //returns
}


/* decode_word  Decodes a word from encoded 4-byte to string
   Parameters
     _input
       4-byte encoded word
     _output
       Address it should store decoded word
   Returns  nothing
   Mangles  A,X,Y
 */
decode_word: {
   ldx #0                     //5 letters
letter:
   lda #0
   ldy #5                     //5 bits
bit:             
   clc                        //shift through all 4 bytes into A
   rol _input+3
   rol _input+2
   rol _input+1
   rol _input
   rol
   dey
   bne bit                    //5 shifts in total
   clc
   adc #'A'-2                 //Convert back to PETSCII
   sta _output:$ffff,x
   inx
   cpx #5
   bne letter
   rts
_input:
   .fill 4,0
}


/* rand  Generates a random byte
   Parameters  nothing
   Returns  random number in A
   Mangles  A
   Notes
     Seed with srand
     If needed, a second random byte can be read from b
 */
rand: {
   inc x
   clc
   lda x:#$00
   eor c:#$c2
   eor a:#$11
   sta a
   adc b:#$37
   sta b
   lsr
   eor a
   adc c
   sta c
   rts
}                
            
/* rand16_max  Generates a 16-bit random number
   Parameters
     _max
       Generated number must be < _max
     _mask_lo and _mask_hi
       Generated number is ANDed with mask to aid subtraction
     _max_mode
       Set to _max_mode_max to check against a maximum value,
       or _max_mode_no_max to skip that check.
   Returns  random number in _output
   Mangles  A
   Note
     You can use this routine generally in one of two ways:  Set
     _mask_hi and _mask_lo to get random bits in specific positions,
     or leave them at $ffff and set _max_hi and _max_lo to get a
     random number no higher than a maximum. Be sure to set _max_mode
     if you wish to check against a maximum number.
 */
rand16_max: {
   jsr rand                   //generate 16-bit number
   and _mask_lo:#$ff
   sta _output
   lda rand.b
   and _mask_hi:#$ff
   sta _output+1
   jmp _max_mode:_max_mode_no_max
_max_mode_max:            
loop:
   lda _output+1              //subtract _max from _output
   cmp _max_hi:#$ff           //while _output > _max
   beq !+
   bcs subtract
   rts
!: lda _output
   cmp _max_lo:#$ff
   bcs subtract
_max_mode_no_max:         
   rts
subtract:
   lda _output                //subtract _max from _output
   sec
   sbc _max_lo
   sta _output
   lda _output+1
   sbc _max_hi
   sta _output+1
   jmp loop
_output:
   .word 0
}
        

/* srand  Seeds the rand using the SID noise channel
   Parameters  none
   Returns  nothing
   Mangles  A
*/
srand: {
   lda #$ff                   //set up SID
   sta $d40e
   sta $d40f
   lda #$80
   sta $d412
   lda $d41b                  //get random number
!: cmp $d41b
   beq !-
   lda $d41b
   sta rand.x
   rts
}
                    


/* is_valid  Checks if a word is valid
   Parameters
     _input
       Address of input word. Defaults to buffer.
   Returns
     C=0  Word is valid
     C=1  Word is invalid
   Mangles A,X
   Notes
     This is the most critical routine in the game.
     Since it must search through a ~10,000 word
     dictionary, entries will take too long if this
     routine is slow.
*/
is_valid: {
   //encode word
   ldx #4                     //5 letters
letter:                  
   lda _input:buffer,x
   sec
   sbc #'A'-2                 //PETSCII to 5-bit code
   ldy #5                     //5 bits
bit:                     
   clc
   ror                        //roll through encoded_word
   ror encoded_word
   ror encoded_word+1
   ror encoded_word+2
   ror encoded_word+3
   dey
   bne bit
   dex
   bpl letter
   lda encoded_word+3         //fix lower bits
   and #%10000000
   ora #%00000001
   sta encoded_word+3
   //search dictionary for word
   m16 #dict:dict_ptr         //reset to beginning of dictionary
word_loop:
   ldx #3                     //4 bytes per word
byte_loop: 
   lda dict_ptr:$ffff,x       //get quarterword
   bne !+                     //stop code?
   sec                        //return invalid
   rts
!: cmp encoded_word,x         //compare with input word
   bne next_word              //no match
   dex                        //next byte
   bpl byte_loop
   clc                        //all 4 bytes matched
   rts                        //return valid
next_word:    
   lda dict_ptr               //advance dict_ptr
   clc
   adc #4
   sta dict_ptr
   bcc word_loop
   inc dict_ptr+1
   jmp word_loop                             
encoded_word: 
   .byte 0,0,0,0
}


/* read_string  Read a string
   Parameters
     _idx
        Initial idx into buffer, used to re-start
        reading a string.
     _buffer (required)
        Address of buffer to store string
     _buffer_len (required)
        Will store at most _buffer_len bytes _not_
        including nul byte
     _getin
        Address of routine to get a character
        Defaults to KERNAL_GETIN
     _chrout
        Address of routine to print a character
        Defaults to KERNAL_CHROUT
     _check_mode
        Possible values are
        check_mode_check or check_mode_no_check
        Defaults to check_mode_check
     _check_string
        Address of string of acceptable characters
        Defaults to alpha
     _check_string_len
        Length of _check_string
     _full_buffer_mode
        Possible values are full_buffer_mode_yes or
        full_buffer_mode_no. If yes, only strings
        filling the buffer will be accepted.
     _echo_mode
        Possible values are echo_mode_fixed_char or
        echo_mode_read_char. Defaults to
        echo_mode_read_char
     _echo_char
        Char to echo in fixed char mode. Defaults
        to '*'
   Returns
     X  number of bytes read, including nul
   Mangles A,X,Y
   Notes
     This routine is intended to be as flexible as
     possible.
*/
read_string: {
   ldx _idx:#0                //initialize idx
loop:
   stx $fb                    //preserve x
!: jsr _getin:KERNAL_GETIN
   beq !-
   ldx $fb                    //restore x
is_return:       
   cmp #$0d                   //done when return is pressed ...
   bne is_delete
   jmp _full_buffer_mode:full_buffer_mode_yes
full_buffer_mode_yes:         
   cpx _buffer_len            //don't return unless at end
   bne loop                   //of buffer
full_buffer_mode_no:          
   lda #0                     //store a nul
   jmp force_store            //also returns
is_delete:
   cmp #$14                   //handle delete specially
   bne is_full
   cpx #0                     //do nothing if at beginning
   beq loop
   dex                        //move tail back and store nul
   lda #0
   jsr store
   dex                        //move tail back again
   jsr echo_mode_read_char    //no fixed echo for delete
   jmp loop
is_full:         
   cpx _buffer_len            //is the buffer full?
   beq loop
check:           
   jmp _check_mode:check_mode_check
check_mode_check:
   ldy _check_string_len:#26  //idx into check string
!: dey
   bmi loop                   //end of check string, invalid
   cmp _check_string:alpha,y
   beq check_ok
   jmp !-
check_mode_no_check:        
check_ok:
   jsr store
   jsr _echo_mode:echo_mode_read_char
!: jmp loop
store:     
   cpx _buffer_len:#$ff       //end of buffer?
   beq !+
force_store:
   sta _buffer:$ffff,x        //store character
   inx
!: rts                        
echo:
echo_mode_fixed_char:         
   lda _echo_char:#'*'
echo_mode_read_char:
   jsr _chrout:KERNAL_CHROUT
   rts
alpha:
   .text "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
}


screen_wordle:
#import "screen_wordle.asm"
           
dict:                           //dict is at end of program
.import binary "dict.bin"
dict_end:   
.const DICT_NUM_WORDS=(dict_end-dict)/4-1
   
program_end:                  
