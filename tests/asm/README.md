# Test Programs

Test programs for the `MZ-800` written in `Z80` assembler.
Use the [z88dk](https://github.com/z88dk/z88dk) assembler to build them.

Usage example:
```
z88dk-z80asm -b TestCharacters.asm
z88dk-appmake +mz --org 0x2000 --audio -b TestCharacters.bin
```
