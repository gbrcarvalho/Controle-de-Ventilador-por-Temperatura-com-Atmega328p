DHT_PORT |= (1 << BIT)

IN AUX, PORT          ; lê IO no AUX
ORI AUX, (1 << BIT)   ; operação or com mascara liga bit
OUT PORT, AUX         ; escreve AUX no IO

; --

DHT_PORT &= ~(1 << BIT)

IN AUX, PORT          ; lê IO no AUX
ANDI AUX, ~(1 << BIT) ; operaçao and com mascara desliga bit
OUT PORT, AUX         ; escreve AUX no IO

; --

DHT_PIN & (1 << BIT)  ; verifica estado do bit

IN AUX, PIN           ; lê IO no AUX
SBRS AUX, BIT         ; pula se o bit estiver setado

; --

!(DHT_PIN & (1 << BIT));

IN AUX, PIN           ; lê IO no AUX
SBRC AUX, BIT         ; pula se o bit estiver limpo

; --

cli()                 ; restaura SREG

IN R20, SREG          ; salva SREG em R20
CLI                   ; desabilita interrupções globais
OUT SREG, R20         ; carrega valor salvo em R20


SEC - set carry, C <- 1
ROR - rotate right through carry
LSR - logical shift right

STS var, AUX          ; escreve o conteudo de AUX em var na sram (var é uma variavel que foi definida anteriormente)
LDS AUX, var          ; lê var da sram no registrador AUX (var é uma variavel que foi definida anteriormente)
