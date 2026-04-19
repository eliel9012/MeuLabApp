#!/usr/bin/env python3
"""Adicionar Secrets.swift ao projeto Xcode"""

from pathlib import Path

pbxproj_path = Path("/Users/eliel/Library/Mobile Documents/com~apple~CloudDocs/apps criados/botapp/MeuLabApp/MeuLabApp.xcodeproj/project.pbxproj")

content = pbxproj_path.read_text()

# Secrets.swift precisa de:
# 1. BuildFile entry
# 2. FileReference entry
# 3. Entrada no array "files" da build phase

# Procurar o maior número usado
import re
numbers = re.findall(r'(\d{3}) /\*', content)
if numbers:
    max_num = max(int(n) for n in numbers)
    secrets_buildfile_id = str(max_num + 1).zfill(3)
    secrets_fileref_id = str(max_num + 2).zfill(3)
else:
    secrets_buildfile_id = "200"
    secrets_fileref_id = "201"

print(f"IDs para usar:")
print(f"  BuildFile: {secrets_buildfile_id}")
print(f"  FileRef: {secrets_fileref_id}")

# 1. Adicionar ao PBXBuildFile section
build_file_line = f"\t\t{secrets_buildfile_id} /* Secrets.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {secrets_fileref_id} /* Secrets.swift */; }};"

# Achar seção de PBXBuildFile
pbx_buildfile_section = content.find("/* Begin PBXBuildFile section */")
pbx_buildfile_end = content.find("/* End PBXBuildFile section */", pbx_buildfile_section)

if pbx_buildfile_section != -1 and pbx_buildfile_end != -1:
    insert_pos = pbx_buildfile_end
    new_line = build_file_line + "\n"
    content = content[:insert_pos] + new_line + content[insert_pos:]
    print("✅ Adicionado PBXBuildFile")
else:
    print("❌ Seção PBXBuildFile não encontrada")

# 2. Adicionar ao PBXFileReference section
file_ref_line = f"\t\t{secrets_fileref_id} /* Secrets.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"MeuLabApp/Core/Secrets.swift\"; sourceTree = SOURCE_ROOT; }};"

pbx_fileref_section = content.find("/* Begin PBXFileReference section */")
pbx_fileref_end = content.find("/* End PBXFileReference section */", pbx_fileref_section)

if pbx_fileref_section != -1 and pbx_fileref_end != -1:
    insert_pos = pbx_fileref_end
    new_line = file_ref_line + "\n"
    content = content[:insert_pos] + new_line + content[insert_pos:]
    print("✅ Adicionado PBXFileReference")
else:
    print("❌ Seção PBXFileReference não encontrada")

# 3. Procurar o array de files da primeira build phase (iOS app)
# Procurar pelo padrão "files = ( ... );" mais próximo ao início
sources_pattern = r'(files = \()((?:.*\n)*?)(\);)'
matches = list(re.finditer(sources_pattern, content))

if matches:
    # Usar primeira ocorrência (iOS app)
    first_match = matches[0]
    files_content = first_match.group(2)
    
    # Verificar se já não está lá
    if secrets_buildfile_id not in files_content:
        # Adicionar antes do closing );
        new_entry = f"\t\t\t\t{secrets_buildfile_id} /* Secrets.swift in Sources */,\n"
        new_files = files_content + new_entry
        
        # Substituir
        old_full = first_match.group(0)
        new_full = first_match.group(1) + new_files + first_match.group(3)
        content = content.replace(old_full, new_full)
        print("✅ Adicionado ao array files da build phase")
    else:
        print("ℹ️  Já existe no array files")
else:
    print("⚠️  Não encontrou array de files para adicionar")

# Salvar
pbxproj_path.write_text(content)
print("\n✅ project.pbxproj atualizado!")
print("\nAgora:")
print("1. Feche o Xcode completamente: Cmd+Q")
print("2. Reabra: open MeuLabApp.xcodeproj")
print("3. Build novamente")
