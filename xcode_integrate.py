#!/usr/bin/env python3
"""
Complete Xcode project integration:
1. Add file references (done previously)
2. Add to PBXBuildFile (done previously)
3. Add to target build phases
4. Add to target resource groups
"""

import re
from pathlib import Path
from typing import List, Optional, Tuple

class XcodeTargetIntegrator:
    def __init__(self, pbxproj_path: str):
        self.pbxproj = Path(pbxproj_path)
        self.content = self.pbxproj.read_text()
        self.original = self.content
        
    def find_target_build_phase_id(self, target_name: str, phase_type: str) -> Optional[str]:
        """
        Find PBXSourcesBuildPhase ID for a given target
        
        phase_type: 'Sources' or 'Resources'
        """
        # Find target by name
        target_pattern = rf'name = {re.escape(target_name)};\s+productName = {re.escape(target_name)};'
        target_match = re.search(target_pattern, self.content)
        
        if not target_match:
            print(f"❌ Target '{target_name}' not found")
            return None
        
        # Find the target's UUID (search backwards for the 24-char hex ID)
        before_match = self.content[:target_match.start()]
        uuids = re.findall(r'([A-F0-9]{24}) = \{', before_match)
        target_uuid = uuids[-1] if uuids else None
        
        if not target_uuid:
            print(f"❌ Could not find UUID for target '{target_name}'")
            return None
        
        print(f"ℹ️  Target '{target_name}' UUID: {target_uuid}")
        
        # Find this target's build phases
        # Look for buildPhases array in this target object
        target_section = re.search(
            rf'{re.escape(target_uuid)} = \{{(.*?)\}}\s*;',
            self.content,
            re.DOTALL
        )
        
        if target_section:
            target_content = target_section.group(1)
            buildphases_match = re.search(r'buildPhases = \((.*?)\);', target_content, re.DOTALL)
            if buildphases_match:
                phases_list = buildphases_match.group(1)
                # Find Sources build phase ID
                phases = re.findall(r'([A-F0-9]{24}) /\* .*?(?:Sources|Resources) Build Phase', phases_list)
                if phases:
                    return phases[0]
        
        return None
    
    def add_file_to_build_phase(self, build_file_id: str, target_name: str, phase_type: str = 'Sources') -> bool:
        """Add file build reference to target's build phase"""
        phase_id = self.find_target_build_phase_id(target_name, phase_type)
        
        if not phase_id:
            print(f"⚠️  Could not find {phase_type} build phase for '{target_name}'")
            return False
        
        # Find the build phase and add file reference to the files array
        # Pattern: isa = PBXSourcesBuildPhase; ... files = ( ... );
        
        pattern = rf'({re.escape(phase_id)} = \{{.*?isa = PBXSourcesBuildPhase;.*?files = \()(.*?)(\);)'
        
        def replacer(match):
            before = match.group(1)
            content = match.group(2)
            after = match.group(3)
            
            # Add file if not already there
            if build_file_id not in content:
                new_line = f'\n\t\t\t\t{build_file_id} /* ... */,'
                content = content + new_line
            
            return before + content + after
        
        new_content = re.sub(pattern, replacer, self.content, count=1, flags=re.DOTALL)
        
        if new_content != self.content:
            self.content = new_content
            print(f"✅ Added {build_file_id} to {target_name} {phase_type} phase")
            return True
        else:
            print(f"⚠️  Could not modify {phase_type} phase for {target_name}")
            return False
    
    def add_file_to_group(self, file_ref_id: str, target_name: str) -> bool:
        """Add file reference to target's resource group"""
        # Find the target's main group
        # This is more complex - often done via PBXGroup sections
        
        # For simplicity with current structure, this might need manual Xcode intervention
        print(f"ℹ️  File reference {file_ref_id} needs to be added to {target_name} group in Xcode")
        return True
    
    def save(self) -> bool:
        if self.content == self.original:
            print("ℹ️  No changes made")
            return True
        
        backup = self.pbxproj.with_suffix('.pbxproj.backup2')
        backup.write_text(self.original)
        
        self.pbxproj.write_text(self.content)
        print(f"✅ Saved: project.pbxproj (backup: {backup.name})")
        return True


def integrate_secrets():
    """Integrate Secrets.plist into targets"""
    project_root = Path(__file__).parent
    pbxproj_path = project_root / "MeuLabApp.xcodeproj/project.pbxproj"
    
    integrator = XcodeTargetIntegrator(str(pbxproj_path))
    
    print("📋 Secrets.plist Integration")
    print("-" * 60)
    
    # Get the IDs we created
    # These were: D916AD0964D84EF1A89E02C6, 8E67D5B72FC44490AD989D19
    secrets_build_id = "8E67D5B72FC44490AD989D19"
    secrets_file_id = "D916AD0964D84EF1A89E02C6"
    
    targets = ["MeuLabApp", "MeuLabWatch", "MeuLabWidgets"]
    
    for target in targets:
        print(f"\n🎯 Target: {target}")
        # Add to build phase
        if not integrator.add_file_to_build_phase(secrets_build_id, target, 'Sources'):
            print(f"⚠️  Fallback: Will add manually in Xcode")
        
        # Add to group
        integrator.add_file_to_group(secrets_file_id, target)
    
    return integrator.save()


def integrate_watchsecrets():
    """Integrate WatchSecrets.swift into watchOS target"""
    project_root = Path(__file__).parent
    pbxproj_path = project_root / "MeuLabApp.xcodeproj/project.pbxproj"
    
    integrator = XcodeTargetIntegrator(str(pbxproj_path))
    
    print("\n📋 WatchSecrets.swift Integration")
    print("-" * 60)
    
    # IDs: E181A3D935D7491286930152, 3909786604B94EE5BE1AD25A
    watchsecrets_build_id = "3909786604B94EE5BE1AD25A"
    watchsecrets_file_id = "E181A3D935D7491286930152"
    
    print(f"\n🎯 Target: MeuLabWatch")
    if not integrator.add_file_to_build_phase(watchsecrets_build_id, "MeuLabWatch", 'Sources'):
        print(f"⚠️  Fallback: May need manual Xcode configuration")
    
    integrator.add_file_to_group(watchsecrets_file_id, "MeuLabWatch")
    
    return integrator.save()


def main():
    print("🔐 Xcode Project Integration - Phase 2")
    print("=" * 60)
    
    project_root = Path(__file__).parent
    pbxproj_path = project_root / "MeuLabApp.xcodeproj/project.pbxproj"
    
    if not pbxproj_path.exists():
        print(f"❌ Not found: {pbxproj_path}")
        return 1
    
    print(f"📁 Project: {project_root.name}\n")
    
    if not integrate_secrets():
        return 1
    
    integrate_watchsecrets()
    
    print("\n" + "=" * 60)
    print("✅ Phase 2 Complete!")
    print("\n📝 Status:")
    print("   • File references added to project.pbxproj")
    print("   • Build file entries created")
    print("   • Build phase integration attempted")
    print("\n🎯 Next:")
    print("   1. Open project in Xcode")
    print("   2. Verify files appear in Navigator")
    print("   3. Check File Inspector → Target Membership")
    print("   4. Compile: xcodebuild build -scheme MeuLabApp")
    
    return 0


if __name__ == "__main__":
    exit(main())
