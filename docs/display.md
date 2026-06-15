# Guia de utilização e funcionamento - Display com multiplexação
Leonardo de Andrade Porto - 225216545

## O que esse código faz?

Dados os 3 valores em DIG1, DIG2 E DIG3, que são aliases para 3 registradores (na versão atual do código, são R17, R18 e R19), esse código mostra esses valores no formato DIG1 DIG2 . DIG3 C em 4 displays de 7 segmentos usando multiplexação.

## Como rodar?

Usando o circuito disponível no repositório, modifique DIG1, DIG2 e DIG3 para os valores desejados, compile e carregue no ATMEGA328, ao rodar, os valores aparecerão no display

## Explicando o código

### Atribuição de constantes

Aqui, definimos os registradores que serão mostrados nos displays em ordem, um registrador AUX para propositos gerais e um registrador CNTRL, que é usado para controlar qual display está ligado a cada instante
```
.include "m328Pdef.inc"


;=============CONSTANTES===============
.def DIG1 = R17
.def DIG2 = R18
.def DIG3 = R19
.def AUX = R16
.def CNTRL = R20

.equ DISPLAY = PORTB
;======================================

.ORG 0x000
```

### Inicializando

Aqui inicializamos os registradores de display (DIG1/2/3) com os valores que queremos mostrar, entretando, no código final, esses valores virão direto da medição. Além disso, usamos aux para configurar saídas e entradas, onde a port B é a saída dos 7 segmentos + ponto e os pinos PC1, PC2, PC3, PC4 são as saídas que controlam cada display (o display só liga se a saída estiver com o bit ligado) 

Por fim, desligamso os displays definindo todos os segmentos com bit 1, assim como os de controle 

```
Inicializacoes:
    ; Inicializando Digitos (os displays mostram DIG1 DIG2. DIG3 C)  [No projeto final, temos que medir a temperatura e guardar a dezena em DIG1, Unidade em DIG2 e primeira casa decimal em DIG3]
    LDI DIG1, 1
    LDI DIG2, 2
    LDI DIG3, 3
    
    ; Configurando Entradas e Saídas
        ; PORTB Tudo saída (Displays)
    LDI AUX, 0xff
    OUT DDRB, AUX 

        ; PORTC tem PC0 como entrada do dht11 e PC1:PC4 como saída do controladores de display [Aqui configuro as 4 portas que estou usando de C como saídas e o resto como entradas, se alguem for usar os pinos da porta C pra outra coisa, pode modificar aqui sem mexer na configuração de IO de PC1, PC2, PC3, PC4]
    LDI AUX, 0b00011110
    OUT DDRC, AUX 

        ; Desliga os displays
    LDI AUX, 0xff
    OUT PORTB, AUX 
    LDI AUX, 0b00011110
    OUT PORTC, AUX
```

### Loop de multiplexação
Nesse loop principal, fazemos a multiplexação: ao inves de mostrar todos os displays ao mesmo tempo, mostramos um de cada vez, isso é feito seguindo o procedimento: 

1. Carregamos o valor do digito que queremos mostrar em AUX
2. Carregamos CNTRL com uma mascara de bits onde todas as saídas estão desligadas menos a do display atual
3. Chamamos Decod, que decodifica o valor que queremos mostrar para a codificação do display de 7 segmentos, sendo que esse valor fica guardado em R1
4. Chamamos Desliga_ponto (nao ocorre para o 2o digito, pois queremos o ponto), que desliga o bit responsável pelo ponto que separa as unidades da primeira casa decimal, que está ligado na codificação da tabela
5. Chamamos Mostra, que joga o valor de R1 para o display
6. Chamamos Atraso, que deixa o valor sendo motrado por um tempo
7. Repete pro próximo dígito 
8. Quando repetir pra todos os digitos volta pro início

```
Principal:
    ;====MOSTRANDO DIGITOS====
    ;   Cada bloco de código faz o seguinte processo: Carrega o digito em aux -> define CNTRL para ligar apenas o display daquele digito, chama decod, chama Desliga_ponto (com exeção de após o digito 2) -> Mostra na tela -> atrasa
    ;=========================

    MOV AUX, DIG1
    LDI CNTRL, 0b00000010
    RCALL Decod
    RCALL Desliga_ponto
    RCALL Mostra
    RCALL Atraso

    MOV AUX, DIG2
    LDI CNTRL, 0b00000100
    RCALL Decod
    ;RCALL Desliga_ponto
    RCALL Mostra
    RCALL Atraso

    MOV AUX, DIG3
    LDI CNTRL, 0b00001000
    RCALL Decod
    RCALL Desliga_ponto
    RCALL Mostra
    RCALL Atraso

    LDI AUX, 0xc 
    LDI CNTRL, 0b00010000
    RCALL Decod
    RCALL Desliga_ponto
    RCALL Mostra
    RCALL Atraso

    RJMP Principal
```

### Sub-rotina Decod
Lemos o endereço da tabela e somamos AUX (que guarda o digito que queremos mostrar) nele para chegar na codificação do digito desejado

Consideramos também se tem carry (se tiver, corrigimos ZH) e por fim, lemos o valor no endereço de Z e guardamos em R1

```
Decod: ; Decodifica AUX e coloca o valor correto em R1
        ; Lê endereço da tabela
    LDI ZH,HIGH(Tabela<<1) 
    LDI ZL,LOW(Tabela<<1) 
        ; Adiciona DIG1 no endereço (pra chegar na posição correta)
    ADD ZL,AUX 
        ; Se houver carry, incrementa ZH, senao pula essa parte
    BRCC le_tab
    inc ZH

    le_tab:

        ; Carrega o número do endereço Z
    LPM R1,Z
    RET
```

### Outras sub-rotinas 
Desliga_ponto faz um or com o valor de R1, ligando o bit do ponto (lembrando que como o display é anodo-comum, bit ligado quer dizer que aquele ponto nao aparece no display)

A sub-rotina "Mostra" apenas joga R1 no display e liga o pino de controle (pino da porta C) daquele display

A sub-rotina faz uma quantidade de contas satisfatoria para um tempo de atraso curto 
```
Desliga_ponto: ; Desliga o .
    LDI AUX, 0b10000000
    OR R1, AUX
    RET

Mostra: ; Mostra o valor de R1 no display
    OUT DISPLAY, R1
        ; Configura para só ter energia em CNTRL (ou seja, só liga o pino de um dos displays)
    OUT PORTC, CNTRL

    RET

Atraso:
    LDI R23, 1
    volta:
    DEC R21
    BRNE volta
    DEC R22
    BRNE volta
    DEC R23
    BRNE volta
    RET
```

### Tabela 
`Tabela: .dw 0x7940, 0x3024, 0x1219, 0x7802, 0x1800, 0x0308, 0x2146, 0x0E06`
Essa tabela foi codificada em sala, cada byte representa uma codificacao de um numero em display de 7 segmentos ânodo comum (40 é 0, 79 é 1, 24 é 2, etc....)