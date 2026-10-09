#!/usr/bin/env python3
"""Cria uma ROM de teste de Super Nintendo (32 KB, LoROM) feita do zero para o P7 Station.

O programa liga a tela e pinta o fundo de roxo, depois fica parado. Serve só para provar
que o emulador abriu e rodou o jogo. Não usa nenhum código ou arte de terceiros.
"""
import sys

rom = bytearray(b"\xff" * 0x8000)
code = bytes([
    0x78,                    # sei
    0x18, 0xFB,              # clc ; xce   (modo nativo)
    0xE2, 0x20,              # sep #$20    (A de 8 bits)
    0xA9, 0x8F, 0x8D, 0x00, 0x21,   # lda #$8F ; sta $2100  (tela apagada)
    0x9C, 0x21, 0x21,        # stz $2121   (cor 0)
    0xA9, 0x1A, 0x8D, 0x22, 0x21,   # lda #$1A ; sta $2122  (roxo: 0x6C1A)
    0xA9, 0x6C, 0x8D, 0x22, 0x21,   # lda #$6C ; sta $2122
    0xA9, 0x0F, 0x8D, 0x00, 0x21,   # lda #$0F ; sta $2100  (tela acesa)
    0x80, 0xFE,              # bra *       (fica parado)
])
rom[0:len(code)] = code

title = b"P7 STATION TESTE".ljust(21, b" ")
hdr = 0x7FC0
rom[hdr:hdr + 21] = title
rom[hdr + 0x15] = 0x20       # LoROM
rom[hdr + 0x16] = 0x00       # só ROM
rom[hdr + 0x17] = 0x05       # 32 KB
rom[hdr + 0x18] = 0x00       # sem SRAM
rom[hdr + 0x19] = 0x01       # região
rom[hdr + 0x1A] = 0x00
rom[hdr + 0x1B] = 0x00       # versão

# vetores: tudo aponta para o início do código ($8000)
for off in (0x7FE4, 0x7FE6, 0x7FE8, 0x7FEA, 0x7FEE, 0x7FF4, 0x7FF8, 0x7FFA, 0x7FFC, 0x7FFE):
    rom[off] = 0x00
    rom[off + 1] = 0x80
# NMI/IRQ: um "rti" logo depois do código
rti = len(code)
rom[rti] = 0x40
for off in (0x7FEA, 0x7FEE, 0x7FFA, 0x7FFE):
    rom[off] = rti & 0xFF
    rom[off + 1] = 0x80 | (rti >> 8)

# soma de verificação
rom[hdr + 0x1C:hdr + 0x20] = b"\xff\xff\x00\x00"
total = sum(rom) & 0xFFFF
rom[hdr + 0x1E] = total & 0xFF
rom[hdr + 0x1F] = total >> 8
comp = total ^ 0xFFFF
rom[hdr + 0x1C] = comp & 0xFF
rom[hdr + 0x1D] = comp >> 8

open(sys.argv[1], "wb").write(rom)
print("ROM criada:", sys.argv[1], len(rom), "bytes")
