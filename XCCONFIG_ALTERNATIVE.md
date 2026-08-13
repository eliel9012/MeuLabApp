# Alternative: Usando xcconfig + Info.plist

Este documento descreve como usar xcconfig para gerenciar configurações, como alternativa ao Secrets.plist.

## 📋 Quando Usar xcconfig

- ✅ Projetos com múltiplos targets (app, watch, extensions)
- ✅ Diferentes configurações por environment (Dev, Staging, Prod)
- ✅ CI/CD pipeline que gera xcconfig dinamicamente
- ✅ Equipes grandes com convenções de build

## 🏗️ Setup: xcconfig + Info.plist

### Arquivo 1: Config.default.xcconfig (Público)

Crie na raiz do projeto com valores placeholder:

```xcconfig
// Config.default.xcconfig
API_BASE_URL = https://app.meulab.fun
API_TOKEN_VALUE = PLACEHOLDER_TOKEN_SET_IN_LOCAL_CONFIG
ENABLE_API_LOGGING = YES
```

**Pode ser commitado** ✅ (sem tokens reais)

### Arquivo 2: Config.local.xcconfig (PRIVADO - .gitignore)

```bash
# Terminal
cp Config.local.xcconfig.example Config.local.xcconfig
```

Edite com valores reais:

```xcconfig
// Config.local.xcconfig
// 🔐 LOCAL ONLY - NEVER COMMIT
API_TOKEN_VALUE = p19Yl1wARrFHjn-4Pg0feQQDeihnRQrMwTUyncjGtgs
// Opcional: override para local testing
// API_BASE_URL = http://localhost:8000
```

**NO .gitignore** ✅:
```
Config.local.xcconfig
**/Config.local.xcconfig
```

---

## ⚙️ Configurar Xcode

### Passo 1: Importar xcconfig nos Build Settings

**Em Xcode:**

1. **Selecione o projeto** (não o target)
2. **Info tab** → ✅ Mostra projeto
3. **Build Settings** → procure por "Config File"
4. **Debug → Config File:** 
   ```
   Config.default.xcconfig
   ```
   (se usar Config.local.xcconfig, importar após)

### Passo 2: Adicionar variáveis ao Info.plist

Edite `MeuLabApp/Info.plist` (como source code):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- ... existing keys ... -->
	
	<!-- API Configuration -->
	<key>API_BASE_URL</key>
	<string>$(API_BASE_URL)</string>
	
	<key>MEULAB_API_TOKEN</key>
	<string>$(API_TOKEN_VALUE)</string>
	
	<key>ENABLE_API_LOGGING</key>
	<string>$(ENABLE_API_LOGGING)</string>
	
	<!-- ... rest of file ... -->
</dict>
</plist>
```

**Resultado:** O build substitui `$(VAR)` com valores do xcconfig

### Passo 3: Usar em Swift

O código Swift já está pronto para ler de Info.plist:

```swift
// Em Secrets.swift - já faz isso:
if let plistValue = Bundle.main.object(forInfoDictionaryKey: "MEULAB_API_TOKEN") as? String {
    return plistValue  // Valor substituído durante build
}
```

---

## 🔄 Fluxo xcconfig no Build

```
1. Xcode lê Config.default.xcconfig
   ↓
2. Se Config.local.xcconfig existe, sobrescreve valores
   ↓
3. Substitui $(VAR) em Info.plist pelos valores
   ↓
4. Resultado: Info.plist com tokens reais no bundle
   ↓
5. Swift lê Bundle.main via Secrets enum
```

---

## 📝 Exemplo Completo

### Arquivo: Config.default.xcconfig

```xcconfig
// Public configuration (SAFE to commit)
PRODUCT_NAME = MeuLabApp
API_BASE_URL = https://app.meulab.fun
API_TOKEN_VALUE = PLACEHOLDER
DEBUG_HTTP_LOGGING = YES
```

### Arquivo: Config.local.xcconfig

```xcconfig
// Local configuration (PRIVATE - .gitignore)
// Copy from Config.local.xcconfig.example

// Override valores do Config.default
API_TOKEN_VALUE = p19Yl1wARrFHjn-4Pg0feQQDeihnRQrMwTUyncjGtgs

// Opcional: local server
// API_BASE_URL = http://localhost:8000
```

### Arquivo: Info.plist

```xml
<key>API_BASE_URL</key>
<string>$(API_BASE_URL)</string>

<key>MEULAB_API_TOKEN</key>
<string>$(API_TOKEN_VALUE)</string>
```

---

## 🔐 Segurança com xcconfig

### Checklist

- ✅ Config.local.xcconfig em .gitignore
- ✅ Config.default.xcconfig commitado (sem tokens reais)
- ✅ Info.plist com `$(VARS)` commitado
- ✅ Build substitui vars → segredo no app, não no repo
- ✅ Cada dev tem seu Config.local.xcconfig local

### Verificar que está seguro

```bash
# 1. Confirmar que .gitignore ignora xcconfig local
git check-ignore Config.local.xcconfig
# (deve retornar: Config.local.xcconfig)

# 2. Ver que não há token no repo
git log -p --all -- "*.plist" | grep -i token
# (não deve mostrar token real)

# 3. Verificar staging area
git diff --staged | grep -i token
# (não deve ter segredo)
```

---

## 🔧 Troubleshooting

### "$(API_BASE_URL) aparece literal no app"

**Causa:** xcconfig não foi incluído no build

**Solução:**
1. **Build Settings** → Project → **Config File**
2. Confirmar que aponta para `Config.default.xcconfig`
3. Clean build: `xcodebuild clean`
4. Rebuild: `xcodebuild build`

### "Valor default em vez de local"

**Causa:** Config.local.xcconfig não foi importado

**Solução:**
```xcconfig
// No topo de Config.default.xcconfig:
#include "Config.local.xcconfig"  // Importa se existir
```

Ou edite Build Settings para incluir local após default.

### "$(VARS) no bundle não substitui"

**Causa:** Info.plist não tem `$(VARS)` syntax

**Solução:**
1. Abra Info.plist em Xcode (como source code: Cmd+Option+Down)
2. Confirme que usa `$(VAR_NAME)` entre `<string>` tags
3. Clean + Rebuild

---

## 🚀 CI/CD com xcconfig

Para GitHub Actions, gerar xcconfig dinamicamente:

```yaml
name: Build with Secrets

on: [push]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Create Config.local.xcconfig
        run: |
          cat > Config.local.xcconfig << EOF
          API_TOKEN_VALUE = ${{ secrets.MEULAB_API_TOKEN }}
          API_BASE_URL = ${{ secrets.API_BASE_URL }}
          EOF
      
      - name: Build
        run: xcodebuild build -scheme MeuLabApp
```

---

## ✅ Comparação: Secrets.plist vs xcconfig

| Aspecto | Secrets.plist | xcconfig |
|--------|---------------|----------|
| **Setup** | 2-3 min | 5 min |
| **Simplicidade** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Escalabilidade** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Multi-target** | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| **CI/CD** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Key-Value** | ✅ Fácil | ✅ Padrão Xcode |
| **Build Vars** | ❌ Não | ✅ Nativo |
| **Recomendado** | Dev local | Projetos grandes |

---

## 📚 Referências

- [Config.default.xcconfig](../Config.default.xcconfig) - Configuração pública
- [Config.local.xcconfig.example](../Config.local.xcconfig.example) - Template privado
- [Apple: Build Configuration Files](https://help.apple.com/xcode/mac/current/#/dev745c5c974)

---

**Última atualização:** 21 de fevereiro de 2026
