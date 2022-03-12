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

word:
   .fill 6,0
encoded_word:
   //.fill 4,0
   .byte $10, $e1, $6a, $81
prompt:
   .text "ENTER A 5 LETTER WORD: "
   .byte 0
wait_prompt:                  
   .text "PRESS ENTER TO START GENERATING WORDS... "
   .byte 0

invalid:
   .text "IN"
valid:
   .text "VALID"
   .byte $0d,0


buffer:
    .fill 6,0
.const buffer_len = *-buffer

start: {
   sei                        //disable BASIC ROM
   lda $1
   and #%11111110
   sta $1
   cli

   lda #6                     //da ba dee da ba di
   sta 53280

   lda #5
   jsr KERNAL_CHROUT

   lda #$ff                   //get the sid noise channel running
   sta $d40e
   sta $d40f
   lda #$80
   sta $d412
   
   PRINT(wait_prompt)         //wait for user
!: jsr KERNAL_GETIN
   cmp #$0d
   bne !-
   lda $d41b                  //get random number
   sta rand.x                 //seed PRNG

   m16 #word:decode_word._output
   
loop:
   jsr random_word
   PRINT(word)
   lda #' '
   jsr KERNAL_CHROUT
   jsr KERNAL_CHROUT
   jsr KERNAL_CHROUT
   jmp loop


/*           
loop:      
   PRINT(prompt)
   mov #5:read_string._buffer_len
   m16 #buffer:read_string._buffer
   jsr read_string
   lda #' '                   //print newline
   ldx #3
!: jsr KERNAL_CHROUT
   dex
   bpl !-

   m16 #invalid:print._string
   jsr is_valid
   bcs !+
   m16 #valid:print._string
!: jsr print
   jmp loop
*/

done:      
   sei                        //enable BASIC ROM
   lda $1
   ora #%00000001
   sta $1
   cli

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
{  //encode word
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
}
{  //search dictionary for word
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
}                             
encoded_word: 
   .byte 0,0,0,0
}


/* read_string  Read a string
   Parameters
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
   ldx #0                     //initialize idx
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
   jsr echo_mode_read_char    //no fixed echo for delete
   dex                        //move tail back and store nul
   lda #0
   jsr store
   dex                        //move tail back again
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



dict:                           //dict is at end of program
.import binary "dict.bin"
dict_end:   
.const DICT_NUM_WORDS=(dict_end-dict)/4-1
            
