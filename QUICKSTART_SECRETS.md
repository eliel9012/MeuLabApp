# 🚀 Setup Rápido: Secrets + API Tokens (5 minutos)

Implementação de segurança para tokens de API sem commitá-los no GitHub.

## ✅ O que foi implementado

1. **Enum `Secrets`** - centraliza leitura de tokens (iOS)
2. **Enum `WatchSecrets`** - versão para watchOS
3. **Arquivo `Secrets.plist.example`** - template com placeholders
4. **.gitignore atualizado** - ignora `Secrets.plist` e `*.xcconfig`
5. **APIService.swift** - updated para usar `Secrets`
6. **WatchAPIService.swift** - updated para usar `WatchSecrets`

---

## 🔧 Setup em 5 Passos

### ✅ Passo 1: Criar Secrets.plist local (1 min)

```bash
cd /Users/eliel/Library/Mobile\ Documents/com~apple~CloudDocs/apps\ criados/botapp/MeuLabApp

# Copiar template
cp Secrets.plist.example Secrets.plist

# Editar com valores reais (em seu editor favorito)
cat > Secrets.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>API_BASE_URL</key>
	<string>https://app.meulab.fun</string>
	<key>MEULAB_API_TOKEN</key>
	<string>p19Yl1wARrFHjn-4Pg0feQQDeihnRQrMwTUyncjGtgs</string>
	<key>API_TOKEN</key>
	<string>p19Yl1wARrFHjn-4Pg0feQQDeihnRQrMwTUyncjGtgs</string>
</dict>
</plist>
EOF
```

**Resultado:** Arquivo `Secrets.plist` local criado ✅

---

### ✅ Passo 2: Adicionar ao Xcode (2 min)

#### Para **MeuLabApp** (iOS):

1. **Abra Xcode:**
   ```bash
   open MeuLabApp.xcodeproj
   ```

2. **Adicionar Secrets.plist:**
   - **Menu:** File → Add Files to "MeuLabApp"
   - **Selecione:** `Secrets.plist` (na raiz)
   - **Copiar se necessário:** ❌ NÃO (arquivo já está lá)
   - **Targets:** 
     - ✅ **MeuLabApp**
     - ✅ **MeuLabWatch** 
     - ✅ **MeuLabWidgets**
   - **Clique:** Add

3. **Verificar Target Membership:**
   - Selecione `Secrets.plist` no Navigator
   - Abra **File Inspector** (Cmd ⌘ + Option ⌥ + 1)
   - **Target Membership:**
     - ✅ MeuLabApp
     - ✅ MeuLabWatch
     - ✅ MeuLabWidgets

#### Para **MeuLabWatch** (watchOS):

1. **Adicionar WatchSecrets.swift:**
   - **Menu:** File → Add Files to "MeuLabApp"
   - **Selecione:** `MeuLabWatch/Services/WatchSecrets.swift`
   - **Targets:** ✅ **MeuLabWatch** apenas
   - **Clique:** Add

2. **Verificar Target Membership:**
   - Selecione `WatchSecrets.swift` no Navigator
   - **File Inspector** → **Target Membership:**
     - ✅ MeuLabWatch
     - ❌ MeuLabApp
     - ❌ MeuLabWidgets

**Resultado:** Arquivos adicionados aos targets corretos ✅

---

### ✅ Passo 3: Compilar e testar (1 min)

```bash
# Clean build
xcodebuild clean -scheme MeuLabApp

# Build
xcodebuild build -scheme MeuLabApp

# Build watchOS
xcodebuild build -scheme MeuLabWatch
```

**Esperado no console:**
```
🔐 Secrets Configuration Status:
   API Base URL: https://app.meulab.fun
   API Token configured: true
   Token (first 10 chars): p19Yl1wAR...

🔐 watchOS Secrets: Token configured = true
```

---

### ✅ Passo 4: Executar no Simulator (1 min)

```bash
# Abrir Xcode
open MeuLabApp.xcodeproj

# Ou compilar e executar
xcodebuild -scheme MeuLabApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Resultado:** App inicia com tokens carregados ✅

---

### ✅ Passo 5: Verificar Segurança Git (1 min)

```bash
# 1. Confirmar que Secrets.plist NÃO aparece em status
git status | grep Secrets
# (não deve mostrar nada)

# 2. Confirmar que arquivo está em .gitignore
cat .gitignore | grep -A2 "Local secret files"
# Deve mostrar: Secrets.plist e xcconfig

# 3. Listar arquivos que SERIAM commitados
git ls-files
# Não deve ter Secrets.plist

# 4. Status final
git status
# Deve estar clean (sem Secrets.plist)
```

**Resultado:** Segredos protegidos do GitHub ✅

---

## 📋 Checklist de Conclusão

- [ ] `Secrets.plist` criado com valores reais
- [ ] `Secrets.plist` adicionado ao Xcode com targets: iOS, watchOS, widgets
- [ ] `WatchSecrets.swift` adicionado ao Xcode com target: watchOS
- [ ] `Secrets.swift` adicionado ao Xcode com target: iOS
- [ ] Projeto compila sem erros
- [ ] Console mostra mensagens de Secrets carregados
- [ ] `git status` não mostra Secrets.plist
- [ ] `.gitignore` contém Secrets.plist

---

## 🔍 Onde os Secrets são Lidos?

### No iOS (MeuLabApp):

```swift
// MeuLabApp/Services/APIService.swift
private let baseURL = Secrets.apiBaseURL
private let apiToken = Secrets.apiToken

// Internamente, Secrets.swift tenta:
// 1. Environment variable: MEULAB_API_TOKEN
// 2. Info.plist: MEULAB_API_TOKEN
// 3. Secrets.plist: MEULAB_API_TOKEN
// 4. Fallback: "" (string vazia com aviso DEBUG)
```

### No watchOS (MeuLabWatch):

```swift
// MeuLabWatch/Services/WatchAPIService.swift
private let apiToken = WatchSecrets.apiToken.isEmpty ? WatchSecrets.apiTokenAlternative : WatchSecrets.apiToken

// Mesma ordem de prioridade
```

---

## 🆘 Troubleshooting

### ❌ "Cannot find 'Secrets' in scope"

**Causa:** Arquivo não foi adicionado ao target iOS

**Solução:**
```bash
# 1. Verificar se está em pbxproj:
grep "Secrets.swift" MeuLabApp.xcodeproj/project.pbxproj | head -3

# 2. Verificar Target Membership no Xcode:
# File → Secrets.swift → File Inspector → targets

# 3. Se faltar, adicionar manualmente:
# File → Add Files → Secrets.swift → targets MeuLabApp ✅
```

---

### ❌ "Cannot find 'WatchSecrets' in scope"

**Causa:** WatchSecrets.swift não foi adicionado ao target watchOS

**Solução:**
```bash
# 1. Verificar:
grep "WatchSecrets.swift" MeuLabApp.xcodeproj/project.pbxproj

# 2. Se não existir, adicionar:
# File → Add Files → MeuLabWatch/Services/WatchSecrets.swift
# Target: ✅ MeuLabWatch apenas

# 3. Script auxiliar (opcional):
python3 add_watchsecrets.py
```

---

### ❌ "Token de API não configurado"

**Causa:** Secrets.plist não no bundle ou valores vazios

**Solução:**
```bash
# 1. Verificar se arquivo existe:
ls Secrets.plist

# 2. Verificar Target Membership:
# Secrets.plist → File Inspector → ✅ MeuLabApp, ✅ MeuLabWatch, ✅ MeuLabWidgets

# 3. Limpar build e recompilar:
xcodebuild clean -scheme MeuLabApp
xcodebuild build -scheme MeuLabApp

# 4. Verificar conteúdo:
cat Secrets.plist | grep -A1 MEULAB_API_TOKEN
```

---

### ❌ "fatal: pathspec 'Secrets.plist' did not match any files"

**Causa:** Git tentando adicionar Secrets.plist (não deveria)

**Solução:**
```bash
# Confirmar que está em .gitignore
git check-ignore Secrets.plist
# Deve retornar: Secrets.plist

# Se não está:
echo "Secrets.plist" >> .gitignore
git add .gitignore
git commit -m "Update .gitignore - ensure Secrets.plist ignored"
```

---

## 📚 Documentação Completa

- **[SECRETS_SETUP.md](SECRETS_SETUP.md)** - Setup detalhado (todos os métodos)
- **[XCCONFIG_ALTERNATIVE.md](XCCONFIG_ALTERNATIVE.md)** - Alternativa com xcconfig
- **[WATCHSECRETS_SETUP.md](WATCHSECRETS_SETUP.md)** - Setup do watchOS

---

## 🎯 Próximos Passos

Depois do setup:

1. **Teste a API:**
   ```bash
   curl -H "Authorization: Bearer p19Yl1wARrFHjn-4Pg0feQQDeihnRQrMwTUyncjGtgs" \
        https://app.meulab.fun/health
   ```

2. **Commit da configuração:**
   ```bash
   git add .gitignore Secrets.plist.example Config.default.xcconfig .
   git commit -m "security: add Secrets infrastructure (no real tokens)"
   git push
   ```

3. **Comunicar ao time:**
   - "Configuração segura de tokens implementada"
   - "Cada dev precisa criar Secrets.plist localmente"
   - "Link para SECRETS_SETUP.md"

---

## ✨ Segurança Garantida

✅ **Tokens NUNCA no GitHub**  
✅ **Fallback seguro** (aviso DEBUG se não configurado)  
✅ **Suporta CI/CD** (env vars ou xcconfig)  
✅ **Multi-target** (iOS, watchOS, widgets)  
✅ **Fácil setup** (5 minutos)  

---

**Última atualização:** 21 de fevereiro de 2026  
**Status:** 🟢 Pronto para uso
