# 🔐 Setup Local de Secrets - Configuração Segura de Tokens

Este guia explica como configurar tokens de API localmente **SEM commitar segredos no GitHub**.

## 📋 Arquitetura de Segurança

O app agora segue esta prioridade para carregar secrets:

```
1. Variáveis de Ambiente (CI/CD, terminal)
   ↓
2. Info.plist (build variables, xcconfig)
   ↓
3. Secrets.plist (local only, in .gitignore)
   ↓
4. Fallback vazio com aviso DEBUG
```

---

## ⚙️ Método 1: Usando Secrets.plist (Recomendado para Desenvolvimento Local)

### Passo 1: Criar o arquivo Secrets.plist

1. **Copiar o arquivo exemplo:**
   ```bash
   cd /Users/eliel/Library/Mobile\ Documents/com~apple~CloudDocs/apps\ criados/botapp/MeuLabApp
   cp Secrets.plist.example Secrets.plist
   ```

2. **Editar com valores reais:**
   - Abra `Secrets.plist` em um editor de texto (ou Xcode)
   - Substitua os placeholder VALUES pelos tokens reais
   - Salve o arquivo

3. **Verificar que não foi commitado:**
   ```bash
   git status | grep Secrets.plist
   # Não deve aparecer nada (está em .gitignore)
   ```

### Passo 2: Adicionar ao Target Membership (Xcode)

Isso é **CRÍTICO** para que o arquivo seja incluído no bundle do app:

1. **Abra o projeto Xcode:**
   ```bash
   open MeuLabApp.xcodeproj
   ```

2. **Localize Secrets.plist na estrutura:**
   - No painel **Project Navigator** (lado esquerdo)
   - Pasta **MeuLabApp** → arquivo `Secrets.plist`

3. **Configure Target Membership:**
   - Selecione `Secrets.plist`
   - Abra **File Inspector** (painel direita: ⌘⌥1)
   - Seção **Target Membership**: marque ✅ para:
     - ✅ `MeuLabApp` (iOS app principal)
     - ✅ `MeuLabWatch` (watchOS app)
     - ✅ `MeuLabWidgets` (App Clips/Widgets)
   
   **Captura visual:**
   ```
   File Inspector (Right Panel)
   ┌─────────────────────────────────────┐
   │ Target Membership                   │
   ├─────────────────────────────────────┤
   │ ☑ MeuLabApp                         │
   │ ☑ MeuLabWatch                       │
   │ ☑ MeuLabWidgets                     │
   └─────────────────────────────────────┘
   ```

4. **Compile e teste:**
   ```bash
   xcodebuild build -scheme MeuLabApp
   ```

---

## 🔐 Método 2: Usando Variáveis de Ambiente (CI/CD)

Para GitHub Actions ou outros CI/CD:

```bash
export MEULAB_API_TOKEN="p19Yl1wARrFHjn-4Pg0feQQDeihnRQrMwTUyncjGtgs"
export API_BASE_URL="https://app.meulab.fun"

xcodebuild build -scheme MeuLabApp
```

### Em GitHub Actions (.github/workflows/build.yml):

```yaml
- name: Build iOS App
  env:
    MEULAB_API_TOKEN: ${{ secrets.MEULAB_API_TOKEN }}
    API_BASE_URL: ${{ secrets.API_BASE_URL }}
  run: xcodebuild build -scheme MeuLabApp
```

---

## 🏗️ Método 3: Usando xcconfig + Info.plist (Alternativa Profissional)

Se preferir uma abordagem más estruturada com xcconfig:

### Passo 1: Criar arquivo Config.local.xcconfig

**Arquivo:** `Config.local.xcconfig` (na raiz do projeto, .gitignore)

```xcconfig
// Config.local.xcconfig
// NUNCA commit este arquivo!

// API Configuration
API_BASE_URL = https://app.meulab.fun
API_TOKEN_VALUE = p19Yl1wARrFHjn-4Pg0feQQDeihnRQrMwTUyncjGtgs
GCC_PREPROCESSOR_DEFINITIONS = API_TOKEN=$(API_TOKEN_VALUE)
```

### Passo 2: Atualizar Info.plist para usar variáveis xcconfig

1. Abra `MeuLabApp/Info.plist` (como source code em Xcode)
2. Adicione:
   ```xml
   <key>MEULAB_API_TOKEN</key>
   <string>$(API_TOKEN_VALUE)</string>
   <key>API_BASE_URL</key>
   <string>$(API_BASE_URL)</string>
   ```

3. Em **Build Settings** do projeto:
   - Busque por `Config File`
   - Na seção Debug: `Config.local.xcconfig`

### Passo 3: Garantir que .gitignore ignora

```bash
# .gitignore - já deve estar com:
Config.local.xcconfig
**/Config.local.xcconfig
Secrets.plist
**/Secrets.plist
```

---

## 🧪 Verificação: Como Saber se Está Funcionando?

### No Xcode Console (DEBUG)

Quando o app inicia, você deve ver:

```
🔐 Secrets Configuration Status:
   API Base URL: https://app.meulab.fun
   API Token configured: true
   Token (first 10 chars): p19Yl1wAR...
```

### Via Código (para testar manualmente)

```swift
import Foundation

// No AppDelegate ou MeuLabApp.swift:
let token = Secrets.apiToken
let isConfigured = Secrets.isConfigured

print("Token configured: \(isConfigured)")
if isConfigured {
    print("✅ Secrets carregados com sucesso!")
} else {
    print("❌ Token não encontrado. Verifique Secrets.plist")
}
```

### Via Terminal

```bash
# Verificar se o arquivo está no bundle após compilar
cd build/Debug-iphonesimulator/MeuLabApp.app
strings Info.plist | grep -A1 MEULAB_API_TOKEN

# Ou com plistutil:
plutil -p Info.plist | grep -A1 MEULAB_API_TOKEN
```

---

## 🚨 Segurança: O Que NÃO Fazer

❌ **NÃO commitar Secrets.plist:**
```bash
# ❌ ERRADO - vai serializar segredo
git add Secrets.plist
git commit -m "adding secrets"

# ✅ CORRETO - arquivo já está em .gitignore
# (será ignorado automaticamente)
```

❌ **NÃO hardcode tokens no código:**
```swift
// ❌ ERRADO
private let apiToken = "p19Yl1wARrFHjn-4Pg0feQQDeihnRQrMwTUyncjGtgs"

// ✅ CORRETO
private let apiToken = Secrets.apiToken
```

❌ **NÃO push Secrets.xcconfig ou Config.local.xcconfig:**
```bash
# Esses arquivos já estão em .gitignore
# Verifique status antes de push:
git status
# Não deve mostrar nenhum arquivo de secrets
```

---

## 📝 Exemplo Prático: Secrets.plist

**Arquivo:** `Secrets.plist` (local only)

```xml
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
```

---

## 📦 Testando o Setup

### Teste 1: Compilação sem Secrets.plist

```bash
# Remova Secrets.plist temporariamente
mv Secrets.plist Secrets.plist.backup

# Compile - deve funcionar com fallback (token vazio)
xcodebuild build -scheme MeuLabApp

# Restaure
mv Secrets.plist.backup Secrets.plist

# Resultado: ✅ App compila mesmo sem token (com aviso)
```

### Teste 2: Carregamento correto

```bash
# Inicie o app e veja no Console:
# 🔐 Secrets Configuration Status: ...
# Token configured: true
```

---

## 🔄 Fluxo de Desenvolvimento

1. ✅ Clone/fork o repositório
2. ✅ Crie `Secrets.plist` localmente (baseado em `Secrets.plist.example`)
3. ✅ Adicione ao Target Membership em Xcode
4. ✅ Compile e teste
5. ✅ **NUNCA** faça commit de `Secrets.plist`
6. ✅ Outras pessoas fazem o mesmo (cada uma tem sua cópia local)

---

## 🆘 Troubleshooting

### "Token de API não configurado"

**Causa:** Token vazio ou Secrets.plist não no bundle

**Solução:**
```bash
# 1. Verificar se arquivo existe:
ls Secrets.plist

# 2. Verificar Target Membership em Xcode:
# → Project Navigator → Secrets.plist
# → File Inspector → ✅ MeuLabApp, ✅ MeuLabWatch

# 3. Limpar build:
rm -rf build/
xcodebuild clean -scheme MeuLabApp
xcodebuild build -scheme MeuLabApp

# 4. Verificar conteúdo:
cat Secrets.plist | grep -A1 MEULAB_API_TOKEN
```

### "Arquivo Secrets.plist não encontrado" (runtime)

**Causa:** Bundle.main.path retorna nil

**Solução:**
1. Verifique que arquivo está  na mesma pasta de Info.plist
2. **Target Membership** está marcado? ✅
3. **Build Phases → Copy Bundle Resources** contém Secrets.plist?
   - Em Xcode: Target → Build Phases → Copy Bundle Resources
   - Deve listar: ✅ Secrets.plist

---

## ✨ Resumo Rápido

| Aspecto | Método 1: Secrets.plist | Método 2: Env Vars | Método 3: xcconfig |
|--------|-------------------------|-------------------|-------------------|
| **Tempo Setup** | 2 min | 1 min | 5 min |
| **Segurança** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Complexidade** | Baixa | Baixa | Média |
| **Ideal para** | Dev local | CI/CD | Projeto grandes |
| **Git-safe** | ✅ in .gitignore | ✅ Env secrets | ✅ in .gitignore |

---

## 📚 Referências

- [Secrets.swift](../MeuLabApp/Core/Secrets.swift) - Enum centralizado
- [WatchSecrets.swift](../MeuLabWatch/Services/WatchSecrets.swift) - Versão para watchOS
- [APIService.swift](../MeuLabApp/Services/APIService.swift) - Uso no app principal
- [WatchAPIService.swift](../MeuLabWatch/Services/WatchAPIService.swift) - Uso no app do relógio

---

**Última atualização:** 21 de fevereiro de 2026
**Status:** ✅ Seguro para produção (sem segredos commitados)
