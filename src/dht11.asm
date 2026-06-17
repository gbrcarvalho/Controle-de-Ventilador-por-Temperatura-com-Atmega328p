; ==================================================================
; dht11.asm - Driver DHT11 em Assembly AVR (ATmega328P)
; ===================================================================

.equ ms100 = ms_98_53
.equ ms20 = ms_24_63
.equ us30 = us_30_8
.equ us40 = us_41_9
.equ us1 = us_1_06

.equ DDR_DHT = DDRC
.equ PORT_DHT = PORTC
.equ PIN_DHT = PINC
.equ BIT_DHT = PC0
.equ HANDSHAKE_ERROR = 0xFF
.equ RECV_CHECKSUM_ERROR = 0xFE
.equ CALC_CHECKSUM_ERROR = 0xFD

handshake_erro:
    SEI
    LDI R24, 0xFF
    RET

checksum_erro_1:
    SEI
    LDI R24, 0xFE
    RET

checksum_erro_2:
    SEI
    LDI R24, 0xFD
    RET

.equ DHT11_MAX_TIMEOUT = 255

; --- resultado da leitura ---
.DSEG

dht_humidity_int:    .byte 1
dht_humidity_dec:    .byte 1
dht_temperature_int: .byte 1
dht_temperature_dec: .byte 1

.CSEG

; =====================================================================
; DHT11_Start - emite o pulso de start para o sensor
; essa função faz uso dos registradores:
;
; R16: AUX
; R25: R_DELAY
;
; I/O:
; PORTX: PORT_DHT
; DDRX: DDRX_DHT
; BITX: BIT_DHT
; =====================================================================

DHT11_Start:
    ; garante HIGH no pino do sensor antes de configurar saída
    IN AUX, PORT_DHT                ; le o valor que esta no PORT, salva em AUX
    ORI AUX, (1 << BIT_DHT)         ; seta somente o bit desejado, os outros permanecem inalterados, em AUX
    OUT PORT_DHT, AUX               ; carrega o valor de AUX em PORT

    ; configura o pino do sensor como saída
    IN AUX, DDR_DHT                 ; le o valor que esta no DDR, salva em AUX
    ORI AUX, (1 << BIT_DHT)         ; seta somente o bit desejado, os outros permanecem inalterados, em AUX
    OUT DDR_DHT, AUX                ; carrega o valor de AUX em DDR

    LDI R_DELAY, ms100              ; carrega o valor no registrador para determinar o delay de 100 ms
    RCALL delay_ms                  ; chama a função para esperar 100 ms

    ; mcu puxa linha para LOW (sinal de start)
    IN AUX, PORT_DHT                ; le o valor que esta no PORT, salva em AUX
    ANDI AUX, ~(1 << BIT_DHT)       ; limpa somente o bit desejado, os outros permanecem inalterados, em AUX
    OUT PORT_DHT, AUX               ; carrega o valor de AUX em PORT

    LDI R_DELAY, ms20               ; carrega o valor no registrador para determinar o delay de 20 ms
    RCALL delay_ms                  ; chama a função para esperar 20 ms

    ; mcu libera barramento puxando para HIGH
    IN AUX, PORT_DHT                ; le o valor que esta no PORT, salva em AUX
    ORI AUX, (1 << BIT_DHT)         ; seta somente o bit desejado, os outros permanecem inalterados, em AUX
    OUT PORT_DHT, AUX               ; carrega o valor de AUX em PORT

    LDI R_DELAY, us30               ; carrega o valor no registrador para determinar o delay de 30 us
    RCALL delay_us                  ; chama a função para esperar 30 us

    ; configura o pino como entrada para ouvir o sensor
    IN AUX, DDR_DHT                 ; le o valor que esta no DDR, salva em AUX
    ANDI AUX, ~(1 << BIT_DHT)       ; limpa somente o bit desejado, os outros permanecem inalterados, em AUX
    OUT DDR_DHT, AUX                ; carrega o valor de AUX em DDR

    ; ativa pull-up interno no pino do sensor
    IN AUX, PORT_DHT                ; le o valor que esta no PORT, salva em AUX
    ORI AUX, (1 << BIT_DHT)         ; seta somente o bit desejado, os outros permanecem inalterados, em AUX
    OUT PORT_DHT, AUX               ; carrega o valor de AUX em PORT

    RET                             ; retorna

; ===========================================================================
; DHT11_CheckResponse - handshake com o sensor
; ===========================================================================

DHT11_CheckResponse:
    ; espera sensor puxar LOW (~80 us) ---
    LDI TEMP, DHT11_MAX_TIMEOUT

espera_low1:
    IN AUX, PIN_DHT
    SBRS AUX, BIT_DHT           ; pula próxima se bit = 1
    RJMP low1_ok                ; está LOW -> proximo passo
    ; ainda HIGH
    LDI R_DELAY, us1
    RCALL delay_us

    DEC TEMP
    BREQ error                  ; timeout esgotado
    RJMP espera_low1

low1_ok:
    ; espera sensor puxar HIGH (~80 us)
    LDI TEMP, DHT11_MAX_TIMEOUT

espera_high:
    IN AUX, PIN_DHT
    SBRC AUX, BIT_DHT           ; pula se bit = 0 (ainda LOW)
    RJMP high_ok                ; está HIGH, proximo passo
    ; ainda LOW
    LDI R_DELAY, us1
    RCALL delay_us

    DEC TEMP
    BREQ error                  ; timeout esgotado
    RJMP espera_high

high_ok:
    ; espera sensor puxar LOW novamente
    LDI TEMP, DHT11_MAX_TIMEOUT

espera_low2:
    IN AUX, PIN_DHT
    SBRS AUX, BIT_DHT           ; pula se bit = 1 (ainda HIGH)
    RJMP low2_ok                ; está LOW, handshake ok
    ; ainda HIGH
    LDI R_DELAY, us1
    RCALL delay_us

    DEC TEMP
    BREQ error
    RJMP espera_low2

low2_ok:
    LDI R24, 1                 ; retorno = 1 (sucesso)
    RET

error:
    LDI R24, 0                 ; retorno = 0 (erro)
    RET

; ===========================================================================
; DHT11_ReadByte - le um byte do sensor
; ===========================================================================

DHT11_ReadByte:
    LDI R24, 0                     ; resultado
    LDI R19, 8                     ; i = 8
    LDI R21, 0b10000000            ; auxiliar usado para ligar os bits
rb_for_loop:
    LDI TEMP, DHT11_MAX_TIMEOUT      ; seta timeout
rb_espera_high:                    ; ~50us em low
    IN AUX, PIN_DHT
    SBRC AUX, BIT_DHT              ; pula se bit = 0 (ainda LOW)
    RJMP rb_high_ok                ; está HIGH, sai do loop
    ; ainda LOW
    DEC TEMP                       ; dec timeout
    BREQ rb_error                  ; se timeout igual a zero pula para retorno erro
    RJMP rb_espera_high            ; enquanto o pino estiver em 0 fica esperando

rb_high_ok:
    ; espera _delay_us(40)
    LDI R_DELAY, us40
    RCALL delay_us
    ; depois de 40us verifica se o pino esta em 1
    IN AUX, PIN_DHT
    SBRS AUX, BIT_DHT
    RJMP rb_for_count              ; se nao pula para o fim do loop
    ; se sim:
    ; seta o bit correspondente em resultado(r24)
    OR R24, R21                    ; se for 1, seta o bit 7, bit 6, bit 5 ...

    ; espera baixar
    LDI TEMP, DHT11_MAX_TIMEOUT      ; seta timeout
rb_espera_low:                     ; espera o bit 1 terminar
    IN AUX, PIN_DHT
    SBRS AUX, BIT_DHT              ; pula se bit = 1 (ainda HIGH)
    RJMP rb_for_count              ; está LOW, sai do loop
    ; ainda LOW
    DEC TEMP                       ; dec timeout
    BREQ rb_error                  ; se timeout igual a zero pula para retorno erro
    RJMP rb_espera_low             ; enquanto o pino estiver em 1 fica esperando
rb_for_count:
    LSR R21                        ; desloca para a direita
    DEC R19                        ; decrementa r19
    BREQ rb_for_end                ; quando r19 chegar em 0 sai do for loop
    RJMP rb_for_loop               ; enquanto nao chegar repete o for loop
rb_for_end:
    RET

rb_error:
    LDI R24, 0
    RET

; ===========================================================================
; DHT11_Read - inicia transmissao, handshake e leitura dos bytes
; ===========================================================================

DHT11_Read:
    RCALL DHT11_Start

    CLI                          ; desabilita interrupções

    RCALL DHT11_CheckResponse
    CPI R24, 0
    BREQ trata_handshake_error

    RCALL DHT11_ReadByte         ; umidade int
    MOV R28, R24

    RCALL DHT11_ReadByte         ; umidade dec
    MOV R27, R24

    RCALL DHT11_ReadByte         ; temperatura int
    MOV R26, R24

    RCALL DHT11_ReadByte         ; temperatura dec
    MOV R25, R24

    RCALL DHT11_ReadByte         ; checksum

    MOV R19, R28
    ADD R19, R27
    ADD R19, R26
    ADD R19, R25

    CPI R24, 0                   ; verifica se o checksum recebido e igual a 0
    BREQ trata_recv_checksum_error

    CP R19, R24                  ; verifica se o acumulado em r19 e igual ao checksum
    BRNE trata_calc_checksum_error

    STS dht_humidity_int, R28
    STS dht_humidity_dec, R27
    STS dht_temperature_int, R26
    STS dht_temperature_dec, R25

    SEI                          ; reabilita interrupções
    LDI R24, 0x01
    RET

trata_handshake_error:
    SEI
    LDI R24, HANDSHAKE_ERROR
    RET

trata_recv_checksum_error:
    SEI
    LDI R24, RECV_CHECKSUM_ERROR
    RET

trata_calc_checksum_error:
    SEI
    LDI R24, CALC_CHECKSUM_ERROR
    RET
