;=============DEFINIÇÕES DISPLAY===============================================
.def DIG1 = R17
.def DIG2 = R18
.def DIG3 = R19
.def AUX = R16
.def CNTRL = R20

.equ SYMB_CELS = 0x0C         ; define o simbolo que representa a grandeza fisica

.equ PORT_DISPLAY = PORTB     ; define a porta de saida dos displays
.equ DDR_DISPLAY = DDRB       ; define a porta de saida dos displays

; independente de qual porta seja utilizada, o mapeamento sera feito da seguinte maneira:
; PINO_0 -> a ... PINO_6 -> g e PINO_7 -> .

.equ PORT_CONTROLE = PORTC    ; define a porta de controle dos displays
.equ DDR_CONTROLE = DDRC      ; define a porta de controle dos displays

.equ DIG1_EN = (1 << PC1)     ; define o pino de controle do DIG1 PC1
.equ DIG2_EN = (1 << PC2)     ; define o pino de controle do DIG2 PC2
.equ DIG3_EN = (1 << PC3)     ; define o pino de controle do DIG3 PC3
.equ CELS_EN = (1 << PC4)     ; define o pino de controle do CELS PC4

.equ INIT_DDR_CONTROLE = (DIG1_EN | DIG2_EN | DIG3_EN | CELS_EN) ; valor para iniciar ddr de controle
;==============================================================================
