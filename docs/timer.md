# Guia de utilização e funcionamento - Timer1 + DHT
**Davi Dias de Carvalho - 222217113**  
**Davi Reis Santos da Silva - 222118873**

---

## O que esse código faz?

Este módulo implementa um temporizador utilizando o Timer1 do ATmega328P para controlar a frequência de leitura do sensor DHT.

O Timer1 é configurado para gerar uma interrupção a cada 1 segundo. A cada interrupção, uma variável na SRAM é incrementada. Quando o intervalo definido em `PERIODO_DHT` é atingido, uma flag é ativada.

A interrupção não realiza a leitura do sensor diretamente. Em vez disso, ela apenas sinaliza ao programa principal que o período mínimo entre leituras foi atingido. O módulo responsável pela comunicação com o DHT pode então realizar uma nova leitura de temperatura e umidade.

Essa abordagem mantém a rotina de interrupção curta e evita executar operações demoradas durante o atendimento da interrupção.

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

### Atribuição de constantes

Inicialmente definimos um registrador auxiliar para uso geral e uma constante que representa o intervalo entre leituras do DHT.

```assembly
.def AUX = R16

.equ PERIODO_DHT = 2
```

Nesse caso, a flag será ativada a cada 2 segundos.

---

### Variáveis na SRAM

Duas variáveis são reservadas na SRAM para permitir a comunicação entre a interrupção do Timer1 e o programa principal.

* `CONTADOR_SEGUNDOS`: contador incrementado pela interrupção a cada segundo. É utilizado para determinar quando o período configurado foi atingido.
* `FLAG_DHT`: flag utilizada para informar ao programa principal que uma nova leitura do sensor deve ser realizada.

```assembly
.DSEG

CONTADOR_SEGUNDOS: .BYTE 1
FLAG_DHT:          .BYTE 1
```

---

### Inicializando o Timer1

A rotina `Timer1_Init` é responsável por configurar completamente o Timer1.

Primeiramente, as variáveis de controle são inicializadas com zero.

```assembly
LDI AUX, 0x00
STS CONTADOR_SEGUNDOS, AUX
STS FLAG_DHT, AUX
```

Em seguida configuramos o Timer1.

```assembly
LDI AUX, 0x00
STS TCCR1A, AUX

LDI AUX, 0b00001101
STS TCCR1B, AUX
```

Nesse valor:

* `WGM12 = 1` → ativa o modo CTC (*Clear Timer on Compare Match*)
* `CS12 = 1` e `CS10 = 1` → seleciona prescaler 1024

No modo CTC o contador é automaticamente reiniciado quando atinge o valor configurado em `OCR1A`.

---

### Configurando o período da interrupção

O valor de comparação é configurado em `OCR1A`.

```assembly
LDI AUX, HIGH(15624)
STS OCR1AH, AUX

LDI AUX, LOW(15624)
STS OCR1AL, AUX
```

Considerando um clock de 16 MHz:

```text
16.000.000 / 1024 = 15.625 Hz
```

Como o contador realiza 15.625 contagens antes de atingir o valor configurado, obtemos aproximadamente 1 segundo entre interrupções.

O valor utilizado é 15624 e não 15625 porque o contador inicia em zero. Assim, a contagem ocorre de 0 até 15624, totalizando 15625 ciclos.

---

### Habilitando as interrupções

Após configurar o Timer1, habilitamos a interrupção Compare Match A.

```assembly
LDI AUX, 0b00000010
STS TIMSK1, AUX
```

Por fim, habilitamos as interrupções globais do microcontrolador.

```assembly
SEI
```

A partir desse momento o Timer1 passa a gerar interrupções automaticamente.

---

### Rotina de interrupção do Timer1

Sempre que ocorre um Compare Match A, a rotina `ISR_Timer1` é executada.

Inicialmente salvamos o contexto utilizado pela interrupção.

```assembly
PUSH AUX

IN AUX, SREG
PUSH AUX
```

Isso garante que a interrupção não altere registradores ou flags utilizados pelo restante do programa.

---

### Contagem de segundos

Em seguida incrementamos o contador armazenado na SRAM.

```assembly
LDS AUX, CONTADOR_SEGUNDOS
INC AUX
STS CONTADOR_SEGUNDOS, AUX
```

Como a interrupção ocorre uma vez por segundo, o valor armazenado em `CONTADOR_SEGUNDOS` corresponde ao número de segundos decorridos desde a última ativação da flag.

---

### Verificação do período de leitura

Após incrementar o contador, verificamos se o intervalo desejado foi atingido.

```assembly
CPI AUX, PERIODO_DHT
BRNE FIM_ISR
```

Caso o valor ainda seja diferente de `PERIODO_DHT`, a interrupção é encerrada.

---

### Levantando a FLAG do DHT

Quando o período configurado é atingido, o contador é reiniciado e a flag é ativada.

```assembly
CLR AUX
STS CONTADOR_SEGUNDOS, AUX

LDI AUX, 1
STS FLAG_DHT, AUX
```

A partir desse momento o programa principal saberá que uma nova leitura do DHT pode ser realizada.

---

### Restaurando o contexto

Antes de finalizar a interrupção, restauramos o estado anterior do processador.

```assembly
POP AUX
OUT SREG, AUX

POP AUX

RETI
```

A instrução `RETI` encerra a interrupção e devolve o controle ao programa principal.

---

### Integração com o programa principal

A interrupção do Timer1 não realiza diretamente a leitura do DHT.

Seu único objetivo é indicar ao programa principal quando o intervalo mínimo entre leituras foi atingido.

Para isso, a ISR ativa a variável `FLAG_DHT`.

```assembly
LDI AUX, 1
STS FLAG_DHT, AUX
```

O programa principal deve monitorar continuamente essa variável.

Quando a flag for ativada, o módulo responsável pela comunicação com o DHT poderá iniciar uma nova leitura de temperatura e umidade.

Após a leitura ser concluída, a flag deve ser limpa para aguardar o próximo período gerado pelo Timer1.

Essa abordagem mantém a rotina de interrupção curta e evita realizar operações demoradas durante o atendimento da interrupção.

---

### Fluxo da ISR

```text
ISR_Timer1
        │
        ▼
Salvar AUX e SREG
        │
        ▼
CONTADOR_SEGUNDOS++
        │
        ▼
CONTADOR_SEGUNDOS == PERIODO_DHT ?
 ├─ Não
 │     │
 │     ▼
 │ Restaurar AUX e SREG
 │     │
 │     ▼
 │    RETI
 │
 └─ Sim
        │
        ▼
CONTADOR_SEGUNDOS = 0
        │
        ▼
FLAG_DHT = 1
        │
        ▼
Restaurar AUX e SREG
        │
        ▼
RETI
```

---

### Fluxo geral do sistema

```text
Timer1
   │
   ▼
ISR_Timer1
   │
   ▼
FLAG_DHT = 1
   │
   ▼
Programa principal verifica FLAG_DHT
   │
   ▼
FLAG_DHT == 1 ?
 ├─ Não ──► Continua executando
 │
 └─ Sim
       │
       ▼
   Ler DHT
       │
       ▼
 FLAG_DHT = 0
       │
       ▼
 Atualizar temperatura
       │
       ▼
    Main
```

Essa estratégia permite utilizar o Timer1 como uma base de tempo precisa para controlar a frequência de leitura do DHT, garantindo que o sensor seja consultado apenas nos intervalos apropriados e mantendo a interrupção rápida e eficiente.