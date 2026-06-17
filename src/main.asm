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
.include "defs.inc"

RJMP Inicio

; =========================================================
; VETOR DE INTERRUPÇÃO DO TIMER1 COMPARE MATCH A
; =========================================================

.ORG OC1Aaddr
    RJMP ISR_Timer1

.ORG 0x0034         ; endereço após o último vetor do 328P
.include "display.asm"
.include "timer.asm"
.include "dht11.asm"

Inicio:
    ; inicializa a pilha
    LDI AUX, HIGH(RAMEND)
    OUT SPH, AUX
    LDI AUX, LOW(RAMEND)
    OUT SPL, AUX

    LDI AUX, 0xFF
    OUT DDRD, AUX
    LDI AUX, 0x00
    OUT PORTD, AUX

    LDI DECIMO, 0 ; valor que será incrementado continuamente - teste
    LDI UNIDADE, 0 ; valor que será incrementado continuamente - teste
    LDI DEZENA, 0 ; valor que será incrementado continuamente - teste
    RCALL Inicializa_Display
    RCALL Timer1_Init

    RCALL DHT11_Read
    CPI R24, 0xFF
    BREQ Fim

    CPI R24, 0xFE
    BREQ Fim

    CPI R24, 0xFD
    BREQ Fim

    LDS R24, dht_temperature_int
    OUT PORTD, R24

    RJMP Main

Erro:
    IN AUX, PORTD
    ORI AUX, (1 << PD7)
    OUT PORTD, AUX

Main:
    STS digi_1, DEZENA
    STS digi_2, UNIDADE
    STS digi_3, DECIMO

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
    LDI  TEMP, 1
    EOR  AUX, TEMP
    ;OUT  PORTD, AUX
    LDI  AUX, 0
    STS  FLAG_DHT, AUX
    RJMP Main

Fim:
    OUT PORTD, R24
