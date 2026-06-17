; ---------------------------------------------
;  PROJETO DE CONTROLE DE VENTILADOR POR TEMPERATURA COM ATMEGA328P
;
;  Disciplina: Programação de Software Básico - MATA49
;  Turma: 2
;  Equipe:
;  Gabriel Silva Carvalho
;  Leonardo de Andrade Porto
;  Davi Reis Santos da Silva
;  Davi Dias de Carvalho
;  Clock do CPU: 16.000.000 Hz
; --------------------------------------------

.include "m328Pdef.inc"
.include "defs.inc"

RJMP Inicio

.ORG 0x0034         ; endereço após o último vetor do 328P
.include "display.asm"

Inicio:
    ; inicializa a pilha
    LDI AUX, HIGH(RAMEND)
    OUT SPH, AUX
    LDI AUX, LOW(RAMEND)
    OUT SPL, AUX

    LDI AUX, 0x00                 ; necessario desligar a serial para nao interferir com o PD0/PD1
    STS UCSR0B, AUX               ; desliga a serial escrevendo 0 em UCSR0B

    LDI DECIMO, 0
    LDI UNIDADE, 0
    RCALL Inicializa_Display

Main:
    STS digi_1, UNIDADE
    STS digi_2, UNIDADE
    STS digi_3, UNIDADE

    RCALL Exibe_Display

    LDI AUX, 1
    ADD DECIMO, AUX
    CPI DECIMO, 10
    BREQ Zera_Decimo
    RJMP Main

Zera_Decimo:
    LDI DECIMO, 0
    LDI AUX, 1
    ADD UNIDADE, AUX
    CPI UNIDADE, 16
    BREQ Zera_Unidade
    RJMP Main

Zera_Unidade:
    LDI UNIDADE, 0
    RJMP Main

Espera:
    PUSH R18
    LDI AUX, 0
    LDI TEMP, 0
    LDI R18, 4
Espera_volta:
    DEC AUX
    BRNE Espera_volta
    DEC TEMP
    BRNE Espera_volta
    DEC R18
    BRNE Espera_volta
    POP R18
    RET
