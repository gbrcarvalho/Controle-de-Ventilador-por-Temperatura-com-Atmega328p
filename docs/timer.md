# Guia de utilização e funcionamento - Timer1 + DHT

**Davi Dias de Carvalho**
**Davi Reis Santos da Silva**

---

## O que esse código faz?

o código configura o `Timer1` do ATmega328P para funcionar como um alarme de hardware rodando em background. Ele conta exatamente 2 segundos de forma independente da CPU. Quando esse tempo limite é atingido, ele dispara uma interrupção (ISR) que levanta uma `Flag` (sinalização), avisando o programa principal, que é seguro realizar uma nova leitura do sensor. 

---

## Como rodar?

1. Adicione os arquivos `timer.asm` e `defs_timer.inc` ao projeto.
2. Compile o programa para o ATmega328P.
3. Grave o arquivo `.hex` no microcontrolador ou carregue-o no SimulIDE.
4. Certifique-se de que o programa principal monitore a variável `FLAG_DHT`.
5. Sempre que a flag for ativada, o módulo responsável pela comunicação com o DHT deverá realizar uma nova leitura do sensor.
6. Após a leitura, a flag deve ser limpa para aguardar o próximo período gerado pelo Timer1.

---

## Explicando o código

O funcionamento lógico baseia-se no modo CTC (Clear Timer on Compare Match).
Em vez de deixar o timer contar até seu limite máximo e transbordar, nós definimos um "teto" matemático. O Timer1 incrementa seu valor a cada pulso de clock (dividido pelo prescaler). Quando esse valor atinge o teto que configuramos, o hardware automaticamente zera o contador e dispara a interrupção `TIMER1_COMPA_vect`.

Dentro da rotina de interrupção, temos um contador auxiliar (`R24`) que registra quantas vezes o alarme de 1 segundo tocou. Quando ele chega a 2, a variável global `FLAG_DHT11` é setada para 1, autorizando o código em C a agir. O contexto do microcontrolador (Registrador de Status - SREG) é sempre salvo e restaurado na pilha (`PUSH`/`POP`) para garantir que o loop do display não sofra nenhuma alteração matemática durante a pausa.

---

### Atribuição de constantes

Para alcançar a precisão de 1 segundo em um microcontrolador operando a 16 MHz, utilizamos as seguintes configurações e constantes nos registradores de hardware:


* #### Prescaler (Divisor de Clock):`1024` 

   * Configurado no registrador `TCCR1B` ativando os bits `CS12` e `CS10`.

   * Reduz a velocidade de contagem do timer: 16.000.000 Hz / 1024 = 15.625 incrementos por segundo.

* #### Modo CTC: Ativo

   * Configurado ativando o bit WGM12 no TCCR1B. Garante que o timer zere sozinho ao atingir o alvo.

```
    LDI AUX, 0x00
    STS TCCR1A, AUX

    ; WGM12 = 1 (CTC)
    ; CS12 = 1 e CS10 = 1 (Prescaler 1024)
    LDI AUX, 0b00001101
    STS TCCR1B, AUX
```

* #### O Teto de Contagem (Compare Match): `0x3D08` (15.624 em decimal)

   * Gravado nos registradores `OCR1AH` (parte alta) e `OCR1AL` (parte baixa).

   * Como o contador começa no 0, contamos até 15.624 para obter exatamente 15.625 ciclos, resultando em cravado 1,000 segundo.

```
   ; Valor de comparação
    ; 15624 = 1 segundo com clock de 16 MHz
    LDI AUX, HIGH(15624)
    STS OCR1AH, AUX
    LDI AUX, LOW(15624)
    STS OCR1AL, AUX
```

* #### Máscara de Interrupção: `0x02`

   * Gravado no registrador `TIMSK1` (bit `OCIE1A`). É a permissão final para que o Timer1 possa interromper o fluxo principal do processador quando atingir o teto de 15.624.

```
; Habilita interrupção Compare Match A
    LDI AUX, 0b00000010
    STS TIMSK1, AUX

    ; Habilita interrupções globais no microcontrolador
    SEI
```

### A Lógica da Interrupção (ISR_Timer1)

A rotina de interrupção (declarada globalmente como TIMER1_COMPA_vect para integração com a linguagem C) é o bloco de código que o processador é obrigado a executar toda vez que o Timer1 atinge o valor de 15.624 (1 segundo cravado).

* #### Proteção de Contexto (Salvar o Estado):
   Como a interrupção "sequestra" o processador no meio de qualquer tarefa que ele estivesse fazendo (como o cálculo do display do loop principal), a primeira ação da ISR é salvar o Registrador de Status (`SREG`) e o registrador auxiliar na Pilha (Stack) usando o comando `PUSH`. Isso garante que as flags matemáticas de cálculos anteriores não sejam corrompidas.

```; -----------------------------------------
    ; Salva contexto
    ; -----------------------------------------
    PUSH AUX
    IN   AUX, SREG
    PUSH AUX
```

* #### A Matemática do Tempo (O multiplicador de 2 segundos): 
   O sensor DHT11 exige um intervalo de leitura de 2 segundos, mas nosso Timer1 está estourando a cada 1 segundo. Para resolver isso, usamos um registrador auxiliar (`R24`) como um Contador de Segundos.
   A cada entrada na interrupção, esse registrador é incrementado (INC). Em seguida, testamos se ele chegou a 2 (`CPI`). Se não chegou, a interrupção encerra.

```; -----------------------------------------
    ; Incrementa contador de segundos
    ; -----------------------------------------
    LDS  AUX, CONTADOR_SEGUNDOS
    INC  AUX
    STS  CONTADOR_SEGUNDOS, AUX

    ; -----------------------------------------
    ; Verifica se passaram 2 segundos (PERIODO_DHT)
    ; -----------------------------------------
    CPI  AUX, PERIODO_DHT
    BRNE FIM_ISR
```

* #### A Comunicação com a Aplicação Principal (A Bandeira / Flag):
   Se o contador de segundos chegar a 2, o sistema zera esse contador (para preparar o próximo ciclo) e altera o valor de um registrador específico (ou variável) para `1`. Essa variável atua como uma Flag (Bandeira).
   Ela serve exclusivamente como um sinal de fumaça: avisa ao loop `main` que o tempo seguro já passou e que a leitura do DHT11 está autorizada.

```
; -----------------------------------------
    ; Zera contador para o próximo ciclo
    ; -----------------------------------------
    CLR  AUX
    STS  CONTADOR_SEGUNDOS, AUX

    ; -----------------------------------------
    ; Levanta FLAG para autorizar leitura do DHT11
    ; -----------------------------------------
    LDI  AUX, 1
    STS  FLAG_DHT, AUX
```

* #### Restauração e Retorno:
   Antes de ir embora, a interrupção puxa de volta os dados da Pilha (`POP`) para os registradores originais e executa o comando `RETI` (Return from Interrupt), devolvendo o controle exatamente para a linha de código onde o processador estava antes do alarme tocar.

```
FIM_ISR:
    ; -----------------------------------------
    ; Restaura contexto da CPU
    ; -----------------------------------------
    POP  AUX
    OUT  SREG, AUX
    POP  AUX

    RETI  ; Retorna da Interrupção
```

