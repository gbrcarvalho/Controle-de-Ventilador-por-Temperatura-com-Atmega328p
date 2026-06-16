; ==================================================================
; dht11.asm — Driver DHT11 em Assembly AVR (ATmega328P)
;
; registradores:
;   AUX–r23  registradores de trabalho
;   r24:r25  retorno de funções de 16 bits (quando necessário)
;   Z (r30:r31) ponteiro para buffer
; ===================================================================

.def R_DELAY = R18

.equ ms_98_53 = 8 ;
.equ ms_110_2 = 9 ;
.equ ms_24_63 = 2 ;
.equ ms_12_31 = 1 ;

.equ us_1_06 = 2 ;
.equ us_30_8 = 160 ;
.equ us_41_9 = 220 ;

.equ ms100 = ms_98_53
.equ ms20 = ms_24_63
.equ us30 = us_30_8
.equ us1 = us_1_06

.equ DDR_DHT = DDRC
.equ PORT_DHT = PORTC
.equ PIN_DHT = PINC
.equ BIT_DHT = PC0

.equ DHT11_MAX_TIMEOUT = 255

; --- resultado da leitura ---
.DSEG

dht_humidity_int:    .byte 1
dht_humidity_dec:    .byte 1
dht_temperature_int: .byte 1
dht_temperature_dec: .byte 1
dht_error:           .byte 1

; buffer interno de 5 bytes (uso interno de DHT11_Read)

dht_buffer:          .byte 5

.CSEG

; =====================================================================
; DHT11_Start - emite o pulso de start para o sensor
; =====================================================================
DHT11_Start:
    ; garante HIGH antes de configurar saída
    IN AUX, PORT_DHT
    ORI AUX, (1 << BIT_DHT)
    OUT PORT_DHT, AUX

    ; configura como saída
    IN AUX, DDR_DHT
    ORI AUX, (1 << BIT_DHT)
    OUT DDR_DHT, AUX

    LDI R_DELAY, ms100
    RCALL delay_ms

    ; puxa linha para LOW (sinal de start)
    IN AUX, PORT_DHT
    ANDI AUX, ~(1 << BIT_DHT)
    OUT PORT_DHT, AUX

    LDI R_DELAY, ms20
    RCALL delay_ms

    ; libera barramento (HIGH)
    IN AUX, PORT_DHT
    ORI AUX, (1 << BIT_DHT)
    OUT PORT_DHT, AUX

    LDI R_DELAY, us30
    RCALL delay_us

    ; configura como entrada para ouvir o sensor
    IN AUX, DDR_DHT
    ANDI AUX, ~(1 << BIT_DHT)
    OUT DDR_DHT, AUX

    ; ativa pull-up interno
    IN AUX, PORT_DHT
    ORI AUX, (1 << BIT_DHT)
    OUT PORT_DHT, AUX

    RET

delay_ms:
    LDI R16, 0
    LDI R17, 0
loop_ms:
    DEC R16           ; 1 ciclos
    BRNE loop_ms   ; se pula 2 ciclos, se nao 1 ciclo, se repete 256 vezes
    DEC R17
    BRNE loop_ms   ; se repete 256 vezes
    DEC R_DELAY
    BRNE loop_ms
    RET

delay_us:
    DEC R_DELAY     ; 1 ciclos
    BRNE delay_us   ; se pula 2 ciclos, se nao 1 ciclo, se repete 256 vezes
    RET
