; =========================================================
; VARIÁVEIS NA SRAM
; =========================================================

.DSEG 

CONTADOR_SEGUNDOS: .BYTE 1 ; armazena os segundos passados
FLAG_DHT:          .BYTE 1 ; flag indicando o momento de ler o DHT

; =========================================================
; ROTINA DE INICIALIZAÇÃO DO TIMER1
; =========================================================

.CSEG

Timer1_Init:

    LDI AUX, 0x00
    STS CONTADOR_SEGUNDOS, AUX
    STS FLAG_DHT, AUX

    ; Modo normal para TCCR1A

    LDI AUX, 0x00
    STS TCCR1A, AUX

    ; WGM12 = 1 (CTC)
    ; CS12 = 1 e CS10 = 1 (Prescaler 1024)

    LDI AUX, 0b00001101
    STS TCCR1B, AUX

    ; Valor de comparação
    ; 15624 = 1 segundo com clock de 16 MHz

    LDI AUX, HIGH(15624)
    STS OCR1AH, AUX

    LDI AUX, LOW(15624)
    STS OCR1AL, AUX

    ; Habilita interrupção Compare Match A

    LDI AUX, 0b00000010
    STS TIMSK1, AUX

    ; Habilita interrupções globais

    SEI

    RET


; =========================================================
; ISR: INTERRUPÇÃO DO TIMER1
; Executa a cada 1 segundo
; =========================================================

ISR_Timer1:

    ; -----------------------------------------
    ; Salva contexto
    ; -----------------------------------------

    PUSH AUX

    IN   AUX, SREG
    PUSH AUX

    ; -----------------------------------------
    ; Incrementa contador de segundos
    ; -----------------------------------------

    LDS  AUX, CONTADOR_SEGUNDOS
    INC  AUX
    STS  CONTADOR_SEGUNDOS, AUX

    ; -----------------------------------------
    ; Verifica se passaram 2 segundos
    ; -----------------------------------------

    CPI  AUX, PERIODO_DHT
    BRNE FIM_ISR

    ; -----------------------------------------
    ; Zera contador
    ; -----------------------------------------

    CLR  AUX
    STS  CONTADOR_SEGUNDOS, AUX

    ; -----------------------------------------
    ; Levanta FLAG para leitura do DHT11
    ; -----------------------------------------

    LDI  AUX, 1
    STS  FLAG_DHT, AUX

FIM_ISR:

    ; -----------------------------------------
    ; Restaura contexto
    ; -----------------------------------------

    POP  AUX
    OUT  SREG, AUX

    POP  AUX

    RETI
