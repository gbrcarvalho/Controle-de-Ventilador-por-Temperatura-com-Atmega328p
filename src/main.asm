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

; =========================================================
; VETOR DE INTERRUPÇÃO DO TIMER1 COMPARE MATCH A
; =========================================================

.ORG OC1Aaddr
    RJMP ISR_Timer1

.ORG 0x0034         ; endereço após o último vetor do 328P
.include "display-5461as.asm"
.include "timer.asm"
.include "delay.asm"
.include "dht11.asm"

Inicio:
    ; inicializa a pilha
    LDI AUX, HIGH(RAMEND)
    OUT SPH, AUX
    LDI AUX, LOW(RAMEND)
    OUT SPL, AUX

    LDI AUX, 0x00                 ; necessario desligar a serial para nao interferir com o PD0/PD1
    STS UCSR0B, AUX               ; desliga a serial escrevendo 0 em UCSR0B

    IN AUX, DDRC                  ; seta a porta pc5 como saida para controlar o rele
    ORI AUX, (1 << PC5)
    OUT DDRC, AUX

    IN AUX, PORTC                  ; limpa a porta pc5
    ANDI AUX, ~(1 << PC5)
    OUT PORTC, AUX

    LDI DECIMO, 0
    LDI UNIDADE, 0
    LDI DEZENA, 0
    RCALL Inicializa_Display
    RCALL Timer1_Init

Main:
    STS digi_1, DEZENA
    STS digi_2, UNIDADE
    STS digi_3, DECIMO

    RCALL Exibe_Display

    ; Verifica se o Timer1 tocou o alarme (Passaram 2 segundos?)
    LDS AUX, FLAG_DHT
    CPI AUX, 1
    BREQ Realiza_Leitura_DHT  ; Se sim, pula para ler o sensor

    ; Se não, volta pro início e continua piscando o display
    RJMP Main

; =========================================================
; ROTINA DE ATUALIZAÇÃO DO SENSOR (Chamada a cada 2 seg)
; =========================================================
Realiza_Leitura_DHT:
    ; regra de segurança: Abaixar a flag imediatamente
    LDI  AUX, 0
    STS  FLAG_DHT, AUX

    ; Chama a leitura física no pino
    RCALL DHT11_Read

    ; Verifica a leitura
    CPI  R24, 0x01
    BRNE Fim_Leitura ; Se deu erro (checksum, timeout), ignora e mantém a temperatura antiga na tela

    ; se deu certo,  extrair os números
    ; Pega a parte inteira da temperatura (Ex: 27°C = 0x1B)
    LDS  TEMP, dht_temperature_int

; =====================================================
; CONTROLE DO RELÉ
; Liga se temperatura >= TEMP_LIMITE
; =====================================================
    CPI TEMP, TEMP_LIMITE_BAIXO
    BRLO Temperatura_Baixa

    CPI TEMP, TEMP_LIMITE_ALTO
    BRGE Temperatura_Alta

    RJMP Continua_Leitura

    Temperatura_Alta:
    RCALL Liga_Rele
    RJMP Continua_Leitura

    Temperatura_Baixa:
    RCALL Desliga_Rele
    RJMP Continua_Leitura

; =====================================================
; CONVERSÃO PARA EXIBIÇÃO
; =====================================================
Continua_Leitura:
    RCALL Hex_Para_BCD_Temp

    ; 2. Pega a parte decimal
    LDS  TEMP, dht_temperature_dec
    MOV  DECIMO, TEMP

Fim_Leitura:
    RJMP Main

; CONVERSÃO HEXADECIMAL PARA DECIMAL (BCD)
Hex_Para_BCD_Temp:
    LDI R18, 0           ; R18 será o nosso contador de dezenas

Subtrai_10:
    CPI TEMP, 10         ; O número atual é menor que 10?
    BRLO Fim_Divisao     ; Se for menor (Branch if Lower), o que sobrou em TEMP é a UNIDADE!

    SUBI TEMP, 10        ; Subtrai 10 da temperatura
    INC R18              ; Conta +1 na dezena
    RJMP Subtrai_10      ; Repete o laço

Fim_Divisao:
    ; Quando cai aqui, R18 tem a dezena e TEMP tem a unidade
    MOV DEZENA, R18
    MOV UNIDADE, TEMP
    RET

; =========================================================
; CONTROLE DO RELÉ
; =========================================================

Liga_Rele:
    SBI PORTC, PC5
    RET

Desliga_Rele:
    CBI PORTC, PC5
    RET

Fim:
    ;OUT PORTD, R24
    RJMP Fim
