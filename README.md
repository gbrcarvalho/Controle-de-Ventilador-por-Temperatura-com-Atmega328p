# Ventilador Automático com Controle por Temperatura

**Universidade Federal da Bahia — Instituto de Computação**  
**Programação de Software Básico — MATA49**

**Equipe:**
- Gabriel Silva Carvalho
- Leonardo de Andrade Porto
- Davi Dias de Carvalho
- Davi Reis Santos da Silva

---

## 1. Introdução

Este relatório descreve o desenvolvimento de um sistema para controle automático de um ventilador com base na temperatura ambiente, programado integralmente em Assembly para o microcontrolador ATmega328P. O projeto foi desenvolvido na disciplina Programação de Software Básico (MATA49) e tem como objetivo demonstrar na prática conceitos fundamentais de sistemas embarcados: interrupções de hardware, comunicação com sensores e multiplexação de displays.

O sistema lê o sensor a cada dois segundos e ajusta o estado do ventilador em tempo real, ligando-o quando a temperatura ultrapassa um limiar (>= 28 C) e desligando-o quando retorna a valores adequados (<= 26 C).

---

## 2. Visão Geral do Sistema

O sistema é composto por quatro blocos funcionais que se comunicam entre si:

- **Módulo DHT11** - leitura de temperatura e umidade via protocolo 1-wire;
- **Módulo Timer1** - gera interrupções periódicas e sinaliza quando é hora de uma nova leitura;
- **Módulo de display** - controla quatro displays de 7 segmentos por multiplexação, exibindo a temperatura no formato `DD.DC`;
- **Módulo do relé** - liga ou desliga o ventilador conforme a temperatura medida.

O programa principal orquestra esses módulos em um laço contínuo: atualiza o display a cada iteração e, quando o Timer1 sinaliza que dois segundos se passaram, realiza a leitura do sensor e atualiza o estado do relé.

---

## 3. Hardware Utilizado

| Componente | Quantidade | Função |
|---|---|---|
| Arduino Nano (ATmega328P) | 1 | Unidade de processamento central |
| Sensor DHT11 | 1 | Medição de temperatura e umidade |
| Display 7 segmentos 5461AS | 1 | Exibição da temperatura em °C |
| Modulo Relé | 1 | Acionamento do ventilador |
| Protoboard e jumpers | — | Montagem do circuito |

### 3.1. Arduino Nano (ATmega328P)

O firmware é 100% Assembly AVR, sem nenhuma biblioteca da plataforma Arduino - toda comunicação ocorre diretamente com os registradores do microcontrolador.

### 3.2. Sensor DHT11

O DHT11 é um sensor digital de temperatura e umidade relativa que se comunica por um protocolo de 1 fio (1-wire). Fornece temperatura em graus Celsius. No projeto, a temperatura é usada para controlar o ventilador e quando o sensor lê uma temperatura >= 28 C, ele liga o relê, só deslingando-o quando a temperatura é <= 26 C.

A ideia é colocar esse relê como interruptor no cabo de energia do ventilador, deixando passar energia apenas quando a temperatura bater um limiar.

### 3.3. Display de 7 Segmentos 5461AS

Usamos um modulo de quatro dígitos de 7 segmentos em configuração de cátodo comum. Para acender um segmento, o microcontrolador coloca o pino de controle do dígito em nível baixo e o pino do segmento em nível alto. A temperatura é exibida no formato DD.DC (ex.: `27.3C`).

---

## 4. Técnicas de Programação

### 4.1. Interrupção de Hardware — Timer1 CTC

O Timer1 foi configurado no modo CTC (Clear Timer on Compare Match). Nesse modo, o contador é zerado automaticamente ao atingir o valor em OCR1A, gerando uma interrupção Compare Match A. Com prescaler de 1024:

```
16.000.000 Hz ÷ 1024 = 15.625 Hz
```

Com `OCR1A = 15.624` (contagem de 0 a 15.624, totalizando 15.625 ciclos), a interrupção dispara exatamente a cada 1 segundo. A cada dois disparos, a flag `FLAG_DHT` é ativada na SRAM, sinalizando ao programa principal que é hora de ler o sensor.

O contexto (registrador AUX e SREG) é salvo na pilha no início e restaurado ao final, garantindo que a interrupção não corrompa o estado do programa principal.

### 4.2. Multiplexação de Displays

Quatro displays controlados de forma estática exigiriam 4 × 7 = 28 pinos apenas para os segmentos. A multiplexação resolve isso: os segmentos de todos os displays são conectados em paralelo (8 pinos, incluindo o ponto, chamados pinos de segmento), e pinos separados controlam qual display está ativo a cada momento (chamados pinos de controle).

Apenas um display é aceso por vez, mas a troca entre eles ocorre em alta velocidade (alguns milissegundos por display). A persistência visual do olho humano integra os flashes e percebe todos os dígitos como acesos simultaneamente. O ciclo de multiplexação segue a sequência:

1. Carrega o valor do dígito atual;
2. Decodifica para o padrão de segmentos via tabela na flash;
3. Envia os dados para a Porta D (segmentos);
4. Ativa apenas o pino de controle do display atual na Porta C;
5. Aguarda alguns milissegundos;
6. Repete para o próximo display.

O ponto decimal é controlado separadamente: a sub-rotina `Desliga_ponto` força o bit 7 do byte (segmento do ponto) para nível baixo, apagando-o — exceto no segundo dígito, onde o ponto deve aparecer para separar unidade do décimo.

### 4.3. Tabela de Decodificação na Memória Flash

Cada dígito de 0 a 9, mais o símbolo C, possui uma codificação própria para o display de ânodo comum: um byte onde cada bit representa um segmento (a, b, c, d, e, f, g, ponto). Como esses valores não mudam durante a execução, são armazenados na memória de programa (flash) com a diretiva `.dw`, formando uma tabela de lookup.

A sub-rotina `Decod` calcula o endereço do byte desejado somando o valor do dígito ao endereço base da tabela no registrador Z (ponteiro de 16 bits ZH:ZL). A instrução `LPM` (Load Program Memory) lê o byte da flash para um registrador de trabalho, sem ocupar RAM.

### 4.4. Protocolo 1-Wire do DHT11

A comunicação com o DHT11 exige controle preciso de temporização em microssegundos. O pino de dados é bidirecional: o microcontrolador o configura como saída para enviar o sinal de início e como entrada para receber os dados.

O protocolo começa com o microcontrolador mantendo o pino em nível baixo por pelo menos 18 ms (sinal de start), depois liberando o barramento. O sensor responde com um pulso de presença e transmite 40 bits: cada bit é codificado pela duração do pulso em nível alto (≈ 26–28 µs = bit 0; ≈ 70 µs = bit 1). O firmware mede essa duração contando ciclos de clock em Assembly.

Ao final, o checksum é verificado: a soma dos quatro bytes de dados deve ser igual ao quinto byte. Se a verificação falha - por ruído ou timeout — a leitura é descartada e o display mantém a última temperatura válida, garantindo robustez ao sistema.

### 4.5. Controle do Relé

A lógica do relé implementa uma histerese de 2 °C para evitar chaveamento excessivo. Dois limiares são definidos em `defs.inc`:

- **`TEMP_LIMITE_ALTO = 28 °C`** - ao atingir ou superar esse valor, o ventilador é ligado;
- **`TEMP_LIMITE_BAIXO = 26 °C`** - abaixo desse valor, o ventilador é desligado.

Na faixa entre 26 °C e 28 °C, nenhuma alteração é feita no estado atual do relé. Essa estratégia protege o relé mecânico de desgaste prematuro e evita oscilações quando a temperatura está próxima ao limiar.

### 4.6. Conversão Hexadecimal para Decimal

O ATmega328P armazena a temperatura como número binário, mas o display precisa dos dígitos individuais separados. A conversão é feita por subtração sucessiva: subtrai-se 10 da temperatura repetidamente, contando quantas vezes é possível - o contador ao final é a dezena, o resto é a unidade.

---

## 5. Organização do Código-Fonte

| Arquivo | Responsabilidade |
|---|---|
| `main.asm` | Programa principal: inicialização, laço de controle, lógica do relé e conversão BCD |
| `defs.inc` | Aliases de registradores, constantes de temperatura e período do timer |
| `display-5461as.asm` | Multiplexação, decodificação e exibição nos 4 displays |
| `timer.asm` | Inicialização do Timer1 e ISR com controle de `FLAG_DHT` |
| `dht11.asm` | Protocolo de comunicação com o sensor DHT11 |
| `delay.asm` | Sub-rotinas de delay calibradas para 16 MHz |
| `m328Pdef.inc` | Definições oficiais dos registradores do ATmega328P |

O vetor de interrupção do Timer1 (`OC1Aaddr`) é configurado no início de `main.asm` para apontar para `ISR_Timer1`. Todo o código das sub-rotinas é posicionado a partir do endereço `0x0034`, após o último vetor de interrupção do ATmega328P, evitando conflitos com a tabela de vetores.

---

## 6. Fluxo de Execução

Ao ser energizado, o microcontrolador executa a inicialização: configura a pilha no topo da SRAM, configura os pinos de I/O, inicializa os displays e o Timer1, e habilita as interrupções globais. O laço principal então opera assim:

1. Atualiza os registradores dos dígitos (DEZENA, UNIDADE, DECIMO);
2. Chama `Exibe_Display`, executando um ciclo completo de multiplexação;
3. Verifica se `FLAG_DHT` está ativa;
4. Se não — retorna ao início (display continua sendo atualizado);
5. Se sim — lê o DHT11, verifica checksum, atualiza temperatura, controla o relé e retorna.

Paralelamente, o Timer1 dispara a ISR a cada segundo, incrementando o contador e ativando a flag a cada dois disparos.

---
