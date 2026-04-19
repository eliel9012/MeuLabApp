#!/usr/bin/env python3
"""Add 6 Bible Reader files to Xcode pbxproj"""

pbx_path = "/Users/eliel/Library/Mobile Documents/com~apple~CloudDocs/apps criados/botapp/MeuLabApp/MeuLabApp.xcodeproj/project.pbxproj"

with open(pbx_path, "r") as f:
    content = f.read()

# (fileRefID, buildFileID, filename)
new_files = [
    ("BRSP01", "BRSP02", "BibleSpeechService.swift"),
    ("BRVM01", "BRVM02", "BibleReaderViewModel.swift"),
    ("BCHR01", "BCHR02", "BibleChapterReaderView.swift"),
    ("BRIT01", "BRIT02", "BibleReadingIntents.swift"),
    ("BRMD01", "BRMD02", "BibleReaderModels.swift"),
    ("BRIG01", "BRIG02", "BibleReaderIntegrationView.swift"),
]

for ref, build, name in new_files:
    if name in content:
        print(f"SKIP: {name} already in pbxproj")
    else:
        print(f"ADDING: {name}")

# 1. PBXBuildFile entries (after BIBR02)
build_entries = ""
for ref, build, name in new_files:
    if name not in content:
        build_entries += "\t\t{} /* {} in Sources */ = {{isa = PBXBuildFile; fileRef = {} /* {} */; }};\n".format(build, name, ref, name)

if build_entries:
    marker = "BIBR02 /* BibleRandomView.swift in Sources */ = {isa = PBXBuildFile; fileRef = BIBR01 /* BibleRandomView.swift */; };"
    content = content.replace(marker, marker + "\n" + build_entries.rstrip())

# 2. PBXFileReference entries (after BIBR01)
ref_entries = ""
for ref, build, name in new_files:
    if name not in content:
        ref_entries += '\t\t{} /* {} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {}; sourceTree = "<group>"; }};\n'.format(ref, name, name)

if ref_entries:
    marker = 'BIBR01 /* BibleRandomView.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = BibleRandomView.swift; sourceTree = "<group>"; };'
    content = content.replace(marker, marker + "\n" + ref_entries.rstrip())

# 3. Models group: add BibleReaderModels after BibleModels
marker = "\t\t\t\tBIBM01 /* BibleModels.swift */,"
if "BRMD01" not in content:
    content = content.replace(marker, marker + "\n\t\t\t\tBRMD01 /* BibleReaderModels.swift */,")

# 4. Services group: add BibleSpeechService after BibleLoader
marker = "\t\t\t\tBIBL01 /* BibleLoader.swift */,"
if "BRSP01" not in content:
    content = content.replace(marker, marker + "\n\t\t\t\tBRSP01 /* BibleSpeechService.swift */,")

# 5. ViewModels group: add BibleReaderViewModel after RemoteRadioViewModel
marker = "\t\t\t\tRR103 /* RemoteRadioViewModel.swift */,"
if "BRVM01" not in content:
    content = content.replace(marker, marker + "\n\t\t\t\tBRVM01 /* BibleReaderViewModel.swift */,")

# 6. Tabs group: add views after BibleRandomView (first occurrence only — in Tabs group 308)
marker = "\t\t\t\tBIBR01 /* BibleRandomView.swift */,"
tabs_adds = ""
if "BCHR01" not in content:
    tabs_adds += "\n\t\t\t\tBCHR01 /* BibleChapterReaderView.swift */,"
if "BRIG01" not in content:
    tabs_adds += "\n\t\t\t\tBRIG01 /* BibleReaderIntegrationView.swift */,"
if tabs_adds:
    content = content.replace(marker, marker + tabs_adds, 1)

# 7. Intents group: add BibleReadingIntents after LabShortcuts
marker = "\t\t\t\t136 /* LabShortcuts.swift */,"
if "BRIT01" not in content:
    content = content.replace(marker, marker + "\n\t\t\t\tBRIT01 /* BibleReadingIntents.swift */,")

# 8. Sources build phase: add all after BIBR02
marker = "\t\t\t\tBIBR02 /* BibleRandomView.swift in Sources */,"
src_adds = ""
for ref, build, name in new_files:
    tag = "{} /* {} in Sources */,".format(build, name)
    if tag not in content:
        src_adds += "\n\t\t\t\t{} /* {} in Sources */,".format(build, name)
if src_adds:
    content = content.replace(marker, marker + src_adds)

with open(pbx_path, "w") as f:
    f.write(content)

print("\nVerifying...")
for ref, build, name in new_files:
    count = content.count(name)
    print(f"  {name}: {count} references")

print("\nDone!")
