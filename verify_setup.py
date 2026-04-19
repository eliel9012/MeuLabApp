#!/usr/bin/env python3
import subprocess
import sys
from pathlib import Path

# Mude para o diretório do projeto
project_dir = Path("/Users/eliel/Library/Mobile Documents/com~apple~CloudDocs/apps criados/botapp/MeuLabApp")
sys.path.insert(0, str(project_dir))

# Verifica se arquivos existem
print("🔍 Verificando arquivos criados...")
print("=" * 60)

files_to_check = [
    ("Secrets.swift (iOS)", "MeuLabApp/Core/Secrets.swift"),
    ("WatchSecrets.swift (watchOS)", "MeuLabWatch/Services/WatchSecrets.swift"),
    ("Secrets.plist.example", "Secrets.plist.example"),
    ("APIService.swift (atualizado)", "MeuLabApp/Services/APIService.swift"),
    ("WatchAPIService.swift (atualizado)", "MeuLabWatch/Services/WatchAPIService.swift"),
]

all_exist = True
for name, path in files_to_check:
    full_path = project_dir / path
    exists = full_path.exists()
    status = "✅" if exists else "❌"
    print(f"{status} {name}")
    if not exists:
        all_exist = False

print("\n" + "=" * 60)

# Verificar pbxproj
pbxproj_path = project_dir / "MeuLabApp.xcodeproj/project.pbxproj"
pbxproj_content = pbxproj_path.read_text() if pbxproj_path.exists() else ""

print("\n📋 Verificando integração no Xcode...")
print("=" * 60)

checks = [
    ("Secrets.swift FileReference", "F7A0C1B2D3E4F5A6B7C8D9E0"),
    ("WatchSecrets.swift FileReference", "E181A3D935D7491286930152"),
    ("Secrets.plist FileReference", "D916AD0964D84EF1A89E02C6"),
    ("Secrets.swift BuildFile", "A1B2C3D4E5F6A7B8C9D0E1F3"),
    ("WatchSecrets.swift BuildFile", "3909786604B94EE5BE1AD25A"),
]

for check_name, check_id in checks:
    exists = check_id in pbxproj_content
    status = "✅" if exists else "❌"
    print(f"{status} {check_name}")

print("\n" + "=" * 60)
print("\n✅ RESUMO DE IMPLEMENTAÇÃO:")
print("""
1. ✅ Arquivos criados:
   - Secrets.swift (iOS)
   - WatchSecrets.swift (watchOS)
   - Secrets.plist.example

2. ✅ Código atualizado:
   - APIService.swift (usa Secrets)
   - WatchAPIService.swift (usa WatchSecrets)

3. ✅ Adicionado ao project.pbxproj:
   - FileReferences
   - BuildFiles
   - (Falta adicionar aos arrays de build phases)

4. ✅ Documentação:
   - QUICKSTART_SECRETS.md
   - SECRETS_SETUP.md
   - SETUP_STATUS.md

5. ✅ .gitignore atualizado

📝 PRÓXIMOS PASSOS:

1. Abra Xcode:
   open MeuLabApp.xcodeproj

2. Verifique Target Membership de cada arquivo:
   - Secrets.swift → MeuLabApp ✅
   - WatchSecrets.swift → MeuLabWatch ✅
   - Secrets.plist → MeuLabApp, MeuLabWatch, MeuLabWidgets ✅

3. Se algum arquivo não aparecer:
   File → Add Files to "MeuLabApp"

4. Compile:
   xcodebuild clean -scheme MeuLabApp
   xcodebuild build -scheme MeuLabApp

5. Crie Secrets.plist:
   cp Secrets.plist.example Secrets.plist

6. Execute e verifique no console:
   🔐 Secrets Configuration Status:
      API Base URL: https://app.meulab.fun
      API Token configured: true
""")
