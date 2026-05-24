#!/usr/bin/env python3
"""Add MacOS9 DesignSystem files to the Xcode project.pbxproj."""

import re
import sys
import shutil

PROJECT = "MeuLabApp.xcodeproj/project.pbxproj"

# 14 DesignSystem files to add
# Each entry: (id_prefix, filename, relative_path_from_root)
DS_FILES = [
    ("DS001", "MacOS9Colors.swift",     "MeuLabApp/DesignSystem/MacOS9/MacOS9Colors.swift"),
    ("DS002", "MacOS9Typography.swift", "MeuLabApp/DesignSystem/MacOS9/MacOS9Typography.swift"),
    ("DS003", "MacOS9Metrics.swift",    "MeuLabApp/DesignSystem/MacOS9/MacOS9Metrics.swift"),
    ("DS004", "MacOS9Modifiers.swift",  "MeuLabApp/DesignSystem/MacOS9/MacOS9Modifiers.swift"),
    ("DS005", "MacOS9TitleBar.swift",   "MeuLabApp/DesignSystem/MacOS9/MacOS9TitleBar.swift"),
    ("DS006", "MacOS9Window.swift",     "MeuLabApp/DesignSystem/MacOS9/MacOS9Window.swift"),
    ("DS007", "MacOS9Button.swift",     "MeuLabApp/DesignSystem/MacOS9/MacOS9Button.swift"),
    ("DS008", "MacOS9Panel.swift",      "MeuLabApp/DesignSystem/MacOS9/MacOS9Panel.swift"),
    ("DS009", "MacOS9Label.swift",      "MeuLabApp/DesignSystem/MacOS9/MacOS9Label.swift"),
    ("DS010", "MacOS9TextField.swift",  "MeuLabApp/DesignSystem/MacOS9/MacOS9TextField.swift"),
    ("DS011", "MacOS9ListRow.swift",    "MeuLabApp/DesignSystem/MacOS9/MacOS9ListRow.swift"),
    ("DS012", "MacOS9Divider.swift",    "MeuLabApp/DesignSystem/MacOS9/MacOS9Divider.swift"),
    ("DS013", "MacOS9Screen.swift",     "MeuLabApp/DesignSystem/MacOS9/MacOS9Screen.swift"),
    ("DS014", "MacOS9Theme.swift",      "MeuLabApp/DesignSystem/MacOS9/MacOS9Theme.swift"),
]

def main():
    # Read current content
    with open(PROJECT, 'r', encoding='utf-8') as f:
        content = f.read()

    # Backup
    shutil.copy2(PROJECT, PROJECT + ".backup_ds")
    print("Backed up to project.pbxproj.backup_ds")

    # ── 1. Add PBXFileReference entries ──────────────────────────────────────
    # Insert before the end marker, after WN15
    ref_entries = []
    for (prefix, filename, path) in DS_FILES:
        ref_id = prefix + "01"
        ref_entries.append(
            f'\t\t{ref_id} /* {filename} */ = {{isa = PBXFileReference; '
            f'lastKnownFileType = sourcecode.swift; '
            f'path = "{path}"; sourceTree = SOURCE_ROOT; }};'
        )
    ref_block = "\n".join(ref_entries)

    END_REF_MARKER = "/* End PBXFileReference section */"
    if END_REF_MARKER not in content:
        print("ERROR: PBXFileReference end marker not found", file=sys.stderr)
        sys.exit(1)
    content = content.replace(
        END_REF_MARKER,
        ref_block + "\n" + END_REF_MARKER
    )
    print(f"Added {len(DS_FILES)} PBXFileReference entries")

    # ── 2. Add PBXBuildFile entries ───────────────────────────────────────────
    build_entries = []
    for (prefix, filename, path) in DS_FILES:
        ref_id  = prefix + "01"
        build_id = prefix + "02"
        build_entries.append(
            f'\t\t{build_id} /* {filename} in Sources */ = '
            f'{{isa = PBXBuildFile; fileRef = {ref_id} /* {filename} */; }};'
        )
    build_block = "\n".join(build_entries)

    END_BF_MARKER = "/* End PBXBuildFile section */"
    if END_BF_MARKER not in content:
        print("ERROR: PBXBuildFile end marker not found", file=sys.stderr)
        sys.exit(1)
    content = content.replace(
        END_BF_MARKER,
        build_block + "\n" + END_BF_MARKER
    )
    print(f"Added {len(DS_FILES)} PBXBuildFile entries")

    # ── 3. Add to Sources build phase (before the closing ); ) ───────────────
    # Anchor: LGM02 is the last entry in Sources
    ANCHOR = "\t\t\t\tLGM02 /* MeuLabApp/Extensions/LiquidGlass+Modifiers.swift in Sources */,"
    if ANCHOR not in content:
        print("ERROR: Sources build phase anchor (LGM02) not found", file=sys.stderr)
        sys.exit(1)

    sources_entries = []
    for (prefix, filename, path) in DS_FILES:
        build_id = prefix + "02"
        sources_entries.append(
            f'\t\t\t\t{build_id} /* {filename} in Sources */,'
        )
    sources_block = "\n".join(sources_entries)

    content = content.replace(
        ANCHOR,
        ANCHOR + "\n" + sources_block
    )
    print(f"Added {len(DS_FILES)} Sources build phase entries")

    # ── 4. Add to PBXGroup (Recovered References) ────────────────────────────
    # Anchor: LGM01 line inside the Recovered References group
    GRP_ANCHOR = "\t\t\t\tLGM01 /* MeuLabApp/Extensions/LiquidGlass+Modifiers.swift */,"
    if GRP_ANCHOR not in content:
        print("ERROR: Group anchor (LGM01) not found", file=sys.stderr)
        sys.exit(1)

    group_entries = []
    for (prefix, filename, path) in DS_FILES:
        ref_id = prefix + "01"
        group_entries.append(
            f'\t\t\t\t{ref_id} /* {filename} */,'
        )
    group_block = "\n".join(group_entries)

    content = content.replace(
        GRP_ANCHOR,
        GRP_ANCHOR + "\n" + group_block
    )
    print(f"Added {len(DS_FILES)} PBXGroup entries")

    # ── Write ─────────────────────────────────────────────────────────────────
    with open(PROJECT, 'w', encoding='utf-8') as f:
        f.write(content)
    print("project.pbxproj updated successfully")

if __name__ == "__main__":
    main()
