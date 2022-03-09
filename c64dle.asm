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
   .byte 0,0,0,0,0,0
encoded_word:
   .byte 0,0,0,0
prompt:
   .text "ENTER A 5 LETTER WORD: "
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

   jsr srand
   ldx #250
!: jsr rand
   sta 1024+000,x
   jsr rand
   sta 1024+250,x
   jsr rand
   sta 1024+500,x
   jsr rand
   sta 1024+750,x
   dex
   bne !-
   jmp *

/*
!: lda $d418                  //choose a random word
   sta $fb
!: cmp $d418                  //wait for a new number
   beq !-
   lda $d418
   sta $fc
   cmp #>DICT_SIZE            //check for too large
   bne !--
   lda $fb
   cmp #<DICT_SIZE
   bne !--
*/

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


/* rand  Generates a random number
   Parameters
     _seed_hi
       High byte, set to seed PRNG and read for result
     _seed_lo
       Low byte, set to seed PRNG and read for result
   Returns  random number in A
   Mangles  A
   Notes
     Do not set the seed to 0 in both _hi and _lo,
     otherwise it will generate 0 over and over again.
 */
rand: {
   lda _seed_hi:#$12
   lsr
   rol _seed_lo
   bcc !+
   eor #$b4
!: sta _seed_hi
   eor _seed_lo:#34
   rts
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
   lda $d418                  //get random number
   sta rand._seed_hi
!: cmp $d418                  //wait for new random number
   beq !-
   lda $d418                  //get random number
   sta rand._seed_lo
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
ncheck_ok:
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
            
