; ---------------------------------------------
;  PROJETO DE CONTROLE DE VENTILADOR POR TEMPERATURA COM ATMEGA328P
;
;  Disciplina: Programação de Software Básico - MATA49
;  Turma: 2
;  Equipe:
;  Gabriel Silva Carvalho
;  Leonardo de Andrade Porto
;  Davi Reis
;  Davi
;  Clock do CPU: 16.000.000 Hz
; --------------------------------------------

.include "m328Pdef.inc"
.include "defs_display.inc"
.include "defs_timer.inc"

; teste
.def DECIMO = R24
.def UNIDADE = R25
.def DEZENA = R26
;

RJMP Inicio

; =========================================================
; VETOR DE INTERRUPÇÃO DO TIMER1 COMPARE MATCH A
; =========================================================

.ORG OC1Aaddr
    RJMP ISR_Timer1

.ORG 0x0034         ; endereço após o último vetor do 328P
.include "display.asm"
.include "timer.asm"

Inicio:
    ; inicializa a pilha
    LDI AUX, HIGH(RAMEND)
    OUT SPH, AUX
    LDI AUX, LOW(RAMEND)
    OUT SPL, AUX

    LDI AUX, 0x01
    OUT DDRD, AUX
    OUT PORTD, AUX

    LDI DECIMO, 0 ; valor que será incrementado continuamente - teste
    LDI UNIDADE, 0 ; valor que será incrementado continuamente - teste
    LDI DEZENA, 0 ; valor que será incrementado continuamente - teste
    RCALL Inicializa_Display
    RCALL Timer1_Init

Main:
    MOV DIG1, DEZENA ;; teste
    MOV DIG2, UNIDADE ;; teste
    MOV DIG3, DECIMO ;; teste

    RCALL Exibe_Display

    LDS AUX, FLAG_DHT
    CPI AUX, 1
    BREQ inverte_portd0

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

inverte_portd0:
    IN   AUX, PORTD
    LDI  R28, 1
    EOR  AUX, R28
    OUT  PORTD, AUX
    LDI  AUX, 0
    STS  FLAG_DHT, AUX
    RJMP Main
