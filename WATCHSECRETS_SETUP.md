# ⚠️ ADICIONAR WatchSecrets.swift ao Xcode

## Problema

O arquivo `MeuLabWatch/Services/WatchSecrets.swift` foi criado, mas não está registrado no projeto Xcode (`project.pbxproj`).

**Erro de compilação:**
```
Cannot find 'WatchSecrets' in scope
```

## Solução (3 passos rápidos)

### 1️⃣ Abrir o projeto Xcode

```bash
open MeuLabApp.xcodeproj
```

### 2️⃣ Adicionar arquivo ao projeto

**No Xcode:**

1. **Menu:** File → Add Files to "MeuLabApp"
   - Ou: **Cmd ⌘ + Option ⌥ + A**

2. **Navegue até:**
   ```
   MeuLabWatch/Services/WatchSecrets.swift
   ```

3. **Marque as checkboxes:**
   - ☑ **Copy items if needed** (NÃO marque - arquivo já está lá)
   - ☑ **Create groups** (Sim, para manter estrutura)
   
4. **Adicione aos targets:**
   - ☑ **MeuLabWatch** (IMPORTANTE!)
   - ☐ MeuLabApp (deixe desmarcado)
   - ☐ MeuLabWidgets (deixe desmarcado)

5. **Clique:** `Add`

### 3️⃣ Compilar

```bash
xcodebuild clean -scheme MeuLabWatch
xcodebuild build -scheme MeuLabWatch
```

**Resultado esperado:** ✅ Sem erros

---

## ✅ Verificar se foi adicionado

```bash
# No terminal:
grep "WatchSecrets.swift" MeuLabApp.xcodeproj/project.pbxproj
```

Deve retornar uma ou mais linhas com "WatchSecrets.swift"

---

## 🎯 Checklist Final

- [ ] Arquivo `MeuLabWatch/Services/WatchSecrets.swift` visível no Xcode Navigator
- [ ] Target Membership: ✅ MeuLabWatch
- [ ] Projeto compila sem erros
- [ ] Console mostra: `🔐 watchOS Secrets: Token configured = true`

---

**Próximo:** After adding file, rebuild and copy `Secrets.plist` to project root.
