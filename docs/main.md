# Guia de Utilização e Funcionamento - Orquestrador do Sistema

## O que esse código faz?

Este é o módulo central (`main.asm`) do nosso sistema de automação térmica. Ele integra todos os códigos, relacionados ao hardware, desenvolvidos pela equipe. Sua função é manter a multiplexação dos displays ativa continuamente enquanto monitora, de forma assíncrona, a flag de tempo gerada pelo Timer1. A cada 2 segundos, ele coleta a temperatura lida pelo sensor DHT11, aciona ou desliga um relé de ventilação com base em limites de temperatura definidos pela equipe e realiza a conversão matemática dos dados de hexadecimal para decimal (BCD) para exibição correta na tela.

## Como rodar?

* ### Compilação:

   * O arquivo deve ser definido como o ponto de entrada principal no seu ambiente de desenvolvimento. Ele fará o link e a montagem automática com as dependências listadas via diretiva `.include` (`defs.inc`, `display-5461as.asm`, `timer.asm`, `delay.asm` e `dht11.asm`).

* ### Hardware:

   * Carregue o arquivo `.hex` gerado diretamente na memória flash do ATmega328P.

* ### Conexões Específicas:

   * O pino de controle do módulo de relé (acionamento do ventilador) deve estar conectado obrigatoriamente à porta `PC5`.

   * Os pinos `PD0` e `PD1` estão livres para uso em outros fins, pois a comunicação serial nativa foi explicitamente desativada via software para evitar interferências.


```assembly
.include
```
Dependências necessárias:

- `defs.inc`
- `display-5461as.asm`
- `timer.asm`
- `delay.asm`
- `dht11.asm`

Após a compilação, será gerado o firmware final em formato `.hex`.

Carregue o arquivo `.hex` diretamente na memória Flash do **ATmega328P**.


## Explicando o código

A arquitetura foi desenhada para priorizar o tempo de resposta do display, utilizando a técnica de Polling para delegar as tarefas mais lentas.

---

### Inicialização (Setup)

Configura o Stack Pointer apontando para o topo da memória RAM. Esse passo é vital na arquitetura AVR para que as sub-rotinas e a interrupção do Timer consigam salvar o contexto e retornar ao fluxo principal sem travar o processador. Em seguida, limpa o registrador `UCSR0B` e define a direção do pino do relé.

```
Inicio:
    ; -----------------------------------------
    ; Inicializa a Pilha (VITAL para interrupções e RCALL)
    ; -----------------------------------------
    LDI AUX, HIGH(RAMEND)
    OUT SPH, AUX
    LDI AUX, LOW(RAMEND)
    OUT SPL, AUX

    ; -----------------------------------------
    ; Desliga a porta Serial (Evita ruído em PD0/PD1)
    ; -----------------------------------------
    LDI AUX, 0x00                 
    STS UCSR0B, AUX               

    ; -----------------------------------------
    ; Configura o pino do Relé (PC5) como Saída e Nível Baixo
    ; -----------------------------------------
    IN AUX, DDRC                  
    ORI AUX, (1 << PC5)
    OUT DDRC, AUX

    IN AUX, PORTC                  
    ANDI AUX, ~(1 << PC5)
    OUT PORTC, AUX
```

### Loop Principal (Polling Assíncrono)

Mantém a rotina `Exibe_Display` em execução infinita. A cada ciclo de máquina, verifica o estado da variável `FLAG_DHT`. Se o valor for `0`, ignora a lógica do sensor e continua desenhando os números. Se for `1`, o processador pausa a tela momentaneamente para executar a leitura física.

```
Main:
    ; -----------------------------------------
    ; Alimenta os registradores de vídeo
    ; -----------------------------------------
    STS digi_1, DEZENA
    STS digi_2, UNIDADE
    STS digi_3, DECIMO

    RCALL Exibe_Display

    ; -----------------------------------------
    ; Polling: Verifica se o Timer1 tocou o alarme (2 seg)
    ; -----------------------------------------
    LDS AUX, FLAG_DHT
    CPI AUX, 1
    BREQ Realiza_Leitura_DHT  ; Se a flag = 1, pausa o display e lê o sensor

    RJMP Main                 ; Se não, volta pro início instantaneamente
```
---

### Controle do Relé (Histerese)

Aplica uma lógica condicional para evitar que o relé fique "batendo" (ligando e desligando rapidamente) caso a temperatura flutue. Ele compara o valor bruto lido com limites superiores e inferiores de atuação. O pino `PC5` só recebe nível lógico alto (`Liga_Rele`) se o teto for atingido, e só recebe nível lógico baixo (`Desliga_Rele`) se o piso for ultrapassado.

```
; Pega a parte inteira da temperatura lida
    LDS  TEMP, dht_temperature_int

    ; -----------------------------------------
    ; Controle de Histerese do Relé
    ; -----------------------------------------
    CPI TEMP, TEMP_LIMITE_BAIXO
    BRLO Temperatura_Baixa       ; Se Temp < Limite Baixo, vai desligar

    CPI TEMP, TEMP_LIMITE_ALTO
    BRGE Temperatura_Alta        ; Se Temp >= Limite Alto, vai ligar

    RJMP Continua_Leitura        ; Se estiver no meio, não faz nada (mantém estado)

Temperatura_Alta:
    RCALL Liga_Rele
    RJMP Continua_Leitura

Temperatura_Baixa:
    RCALL Desliga_Rele
    RJMP Continua_Leitura
```

---

### Conversão BCD (`Hex_Para_BCD_Temp`)

Como o display de 7 segmentos exige dígitos individuais, esta rotina transforma o valor hexadecimal contínuo entregue pelo sensor em variáveis separadas de dezena e unidade. O algoritmo matemático utiliza um laço de repetição com subtrações sucessivas do valor 10. O número de ciclos completos define a dezena, e o resíduo final da subtração define a unidade.

```
Hex_Para_BCD_Temp:
    LDI R18, 0           ; Inicia o contador de dezenas em 0

Subtrai_10:
    CPI TEMP, 10         ; O número atual é menor que 10?
    BRLO Fim_Divisao     ; Se sim, acabou! O que sobrou em TEMP é a UNIDADE.

    SUBI TEMP, 10        ; Subtrai 10 do valor total
    INC R18              ; Soma 1 na casa da DEZENA
    RJMP Subtrai_10      ; Repete o laço

Fim_Divisao:
    MOV DEZENA, R18      ; Salva a dezena calculada
    MOV UNIDADE, TEMP    ; Salva a unidade que sobrou
    RET
```


## Atribuição de Constantes

O comportamento do orquestrador depende de constantes fornecidas por arquivos de definição e pela própria arquitetura AVR.

* `RAMEND`: Aponta para o endereço mais alto da SRAM, utilizado para a alocação segura da pilha do sistema.

---

* `OC1Aaddr`: Endereço fixo na memória de programa (Flash) que aponta para o vetor da interrupção gerada pelo Compare Match A do Timer1.

---

* `TEMP_LIMITE_ALTO`: Parâmetro importado do arquivo de definições (`defs.inc`) que estabelece o gatilho de temperatura para ligar a ventilação.

---

* `TEMP_LIMITE_BAIXO`: Parâmetro importado do arquivo de definições que estabelece a temperatura de conforto para o desligamento da ventilação.

---

