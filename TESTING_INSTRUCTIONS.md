# Como Testar o App com Logging Ativado

## O Que Foi Feito

Adicionei logging detalhado ao `AppState.swift` para rastrear:
- 📡 Chamadas à API
- ✅ Dados recebidos
- 📝 Atualizações de estado
- ❌ Erros

Também adicionei botões de refresh manual nas abas ACARS e ADS-B.

## Passos para Testar

### 1. Build e Execute no Xcode

```bash
cd /Users/eliel/Downloads/botapp/MeuLabApp
open MeuLabApp.xcodeproj
```

1. Conecte seu iPhone/iPad ao Mac
2. Selecione o dispositivo como target
3. Pressione ⌘R para executar
4. Abra o Console (⌘⇧Y)

### 2. Teste ACARS

1. **Abra a aba ACARS no app**
2. **Observe o console do Xcode** - você deve ver:
   ```
   [ACARS] 🔄 Starting refresh...
   [ACARS] 📡 Fetching summary...
   [ACARS] ✅ Summary received: XXX messages today
   [ACARS] 📡 Fetching messages...
   [ACARS] ✅ Messages received: XX messages
   [ACARS]   First message: FLIGHT - LABEL
   [ACARS] 📝 Updating messages: XX messages
   [ACARS] ✅ Refresh completed successfully
   ```

3. **Toque no botão de refresh** (⟳) no canto superior direito
4. **Verifique se as mensagens aparecem** na seção "Mensagens Recentes"

### 3. Teste ADS-B Movement

1. **Abra a aba ADS-B no app**
2. **Observe o console do Xcode** - você deve ver:
   ```
   [ADSB] 🔄 Starting refresh...
   [ADSB] 📡 Fetching summary and aircraft list...
   [ADSB] ✅ Summary received: XX aircraft
   [ADSB]   Movement: climbing=X, descending=X, cruising=X
   [ADSB] 📝 Updating summary (changed)
   ```

3. **Verifique os cards de movimento**:
   - Devem mostrar números (ex: 7, 11, 13)
   - Toque em cada card
   - Deve abrir lista de aeronaves

4. **Toque no botão de refresh** (⟳) no canto superior direito

## O Que Procurar no Console

### ✅ Cenário Bom (Funcionando)

```
[ACARS] 🔄 Starting refresh...
[ACARS] 📡 Fetching summary...
[ACARS] ✅ Summary received: 603 messages today
[ACARS] 📡 Fetching messages...
[ACARS] ✅ Messages received: 20 messages
[ACARS]   First message: JJ3263 - H1
[ACARS] 📝 Updating messages: 20 messages
[ACARS] ✅ Refresh completed successfully
```

### ❌ Cenário Ruim (Com Problema)

**Erro de rede:**
```
[ACARS] ❌ Error during refresh: The Internet connection appears to be offline
[ACARS]   API Error details: networkError(...)
```

**Erro de autenticação:**
```
[ACARS] ❌ Error during refresh: Não autorizado
[ACARS]   API Error details: unauthorized
```

**Erro de decodificação:**
```
[ACARS] ❌ Error during refresh: Erro ao processar dados
[ACARS]   API Error details: decodingError(...)
```

**Dados não mudando:**
```
[ACARS] ✅ Summary received: 603 messages today
[ACARS] ⏭️ Summary unchanged, skipping update
[ACARS] ✅ Messages received: 20 messages
[ACARS] ⏭️ Messages unchanged, skipping update
```

## Possíveis Problemas e Soluções

### Problema 1: "Skipping refresh - already loading"

**Sintoma:** Logs mostram apenas `⏭️ Skipping refresh - already loading`

**Causa:** Múltiplas chamadas simultâneas ao refresh

**Solução:** Aguarde 10 segundos e tente novamente

### Problema 2: Dados recebidos mas "unchanged"

**Sintoma:** Logs mostram `✅ Messages received` mas `⏭️ Messages unchanged`

**Causa:** Comparação de arrays falhando

**Solução:** Vou criar um fix para forçar atualização

### Problema 3: Erro de rede

**Sintoma:** `❌ Error: The Internet connection appears to be offline`

**Causa:** App não consegue conectar à API

**Soluções:**
1. Verifique se está conectado à internet
2. Teste se `https://app.meulab.fun` está acessível
3. Execute `./test_api.sh` no terminal

### Problema 4: Erro 401 Unauthorized

**Sintoma:** `❌ Error: Não autorizado`

**Causa:** Token da API expirado

**Solução:** Atualize o token em `APIService.swift` linha 34

### Problema 5: Nenhum log aparece

**Sintoma:** Console vazio, sem logs de ACARS ou ADSB

**Causa:** App não está chamando refresh

**Soluções:**
1. Verifique se o timer está rodando
2. Toque no botão de refresh manual (⟳)
3. Force quit e reabra o app

## Próximos Passos

Após executar os testes, me informe:

1. **Logs do console** - Copie e cole os logs que aparecem
2. **O que você vê no app** - Descreva o que aparece (ou não aparece)
3. **Erros específicos** - Se houver mensagens de erro

Com essas informações, posso identificar exatamente o problema e criar o fix apropriado.

## Atalhos Úteis no Xcode

- **⌘R** - Build e executar
- **⌘.** - Parar execução
- **⌘⇧Y** - Mostrar/ocultar console
- **⌘K** - Limpar console
- **⌘F** - Buscar no console (procure por "[ACARS]" ou "[ADSB]")
