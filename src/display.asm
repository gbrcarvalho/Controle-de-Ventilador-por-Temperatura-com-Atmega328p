Inicializa_Display:
    ; Inicializando Digitos (os displays mostram DIG1 DIG2. DIG3 C)
    LDI DIG1, 0
    LDI DIG2, 0
    LDI DIG3, 0

    ; Configurando Saídas
    LDI AUX, 0xff
    OUT DDR_DISPLAY, AUX

    ; Configura saidas de controle
    LDI AUX, INIT_DDR_CONTROLE
    OUT DDR_CONTROLE, AUX

    ; Desliga os displays
    LDI AUX, 0xff
    OUT PORT_DISPLAY, AUX
    LDI AUX, 0x00
    OUT PORT_CONTROLE, AUX
    RET

Exibe_Display:
    ;====MOSTRANDO DIGITOS====
    ;   Cada bloco de código faz o seguinte processo: Carrega o digito em aux -> define CNTRL para ligar apenas o display daquele digito, chama decod, chama Desliga_ponto (com exeção de após o digito 2) -> Mostra na tela -> atrasa
    ;=========================
    MOV AUX, DIG1
    LDI CNTRL, DIG1_EN
    RCALL Decod
    RCALL Desliga_ponto
    RCALL Mostra
    RCALL Atraso

    MOV AUX, DIG2
    LDI CNTRL, DIG2_EN
    RCALL Decod
    ;RCALL Desliga_ponto
    RCALL Mostra
    RCALL Atraso

    MOV AUX, DIG3
    LDI CNTRL, DIG3_EN
    RCALL Decod
    RCALL Desliga_ponto
    RCALL Mostra
    RCALL Atraso

    LDI AUX, SYMB_CELS
    LDI CNTRL, CELS_EN
    RCALL Decod
    RCALL Desliga_ponto
    RCALL Mostra
    RCALL Atraso

    RET

Decod:
    ; Decodifica AUX e coloca o valor correto em R1
    ; Lê endereço da tabela
    LDI ZH,HIGH(Tabela<<1)
    LDI ZL,LOW(Tabela<<1)

    ; Adiciona AUX no endereço (pra chegar na posição correta)
    ADD ZL,AUX

    ; Se houver carry, incrementa ZH, senao pula essa parte
    BRCC le_tab
    INC ZH

le_tab:
    ; Carrega o número do endereço Z
    LPM R1,Z
    RET

Desliga_ponto:
    LDI AUX, 0b10000000
    OR R1, AUX
    RET

Mostra:
    ; Mostra o valor de R1 no display
    OUT PORT_DISPLAY, R1
    ; Configura para só ter energia em CNTRL (ou seja, só liga o pino de um dos displays)
    OUT PORT_CONTROLE, CNTRL
    RET

Atraso:
    LDI R21, 0
    LDI R22, 0
    LDI R23, 1
    volta:
    DEC R21
    BRNE volta
    DEC R22
    BRNE volta
    DEC R23
    BRNE volta
    RET

Tabela: .dw 0x7940, 0x3024, 0x1219, 0x7802, 0x1800, 0x0308, 0x2146, 0x0E06
