.include "m328Pdef.inc"
.include "defs_display.inc"

; teste
.def DECIMO = R24
.def UNIDADE = R25
.def DEZENA = R26
;

RJMP Inicio

.include "display.asm"

Inicio:
    ; inicializa a pilha
    LDI AUX, HIGH(RAMEND)
    OUT SPH, AUX
    LDI AUX, LOW(RAMEND)
    OUT SPL, AUX

    LDI DECIMO, 0 ; valor que será incrementado continuamente - teste
    LDI UNIDADE, 0 ; valor que será incrementado continuamente - teste
    LDI DEZENA, 0 ; valor que será incrementado continuamente - teste
    RCALL Inicializa_Display

Main:
    MOV DIG1, DEZENA ;; teste
    MOV DIG2, UNIDADE ;; teste
    MOV DIG3, DECIMO ;; teste

    RCALL Exibe_Display

; teste, codigo fica incrementando o valor
    INC DECIMO
    CPI DECIMO, 10
    BREQ vai_um_unidade
    RJMP Main

vai_um_unidade:
    LDI DECIMO, 0
    INC UNIDADE
    CPI UNIDADE, 10
    BREQ vai_um_dezena
    RJMP Main

vai_um_dezena:
    LDI DECIMO, 0
    LDI UNIDADE, 0
    INC DEZENA
    CPI DEZENA, 10
    BREQ zera
    RJMP Main

zera:
    LDI DECIMO, 0
    LDI UNIDADE, 0
    LDI DEZENA, 0
    RJMP Main
; apagar esse codigo de teste
