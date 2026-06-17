; =====================================================================
; delay_ms
;
; R16: AUX
; R25: R_DELAY
;
; I/O:
; PORTX: PORT_DHT
; DDRX: DDRX_DHT
; BITX: BIT_DHT
; =====================================================================

.def R_DELAY = R25

.equ ms_98_53 = 8 ;
.equ ms_110_2 = 9 ;
.equ ms_24_63 = 2 ;
.equ ms_12_31 = 1 ;

.equ us_1_06 = 2 ;
.equ us_30_8 = 160 ;
.equ us_41_9 = 220 ;

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

.undef R_DELAY
