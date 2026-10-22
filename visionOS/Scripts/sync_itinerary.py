#!/usr/bin/env python3
"""Export the iPhone trip's VData into a deterministic visionOS resource."""

import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "MeuLabApp/Views/Tabs/ViagemView.swift"
OUTPUT = ROOT / "visionOS/Resources/TripItinerary.json"

text = SOURCE.read_text()
start = text.index("private struct VEvent: Identifiable")
end = text.index("// MARK: - Badge", start)
models = text[start:end]
models = models.replace("VEvent: Identifiable", "VEvent: Identifiable, Codable", 1)
models = models.replace("VDay: Identifiable", "VDay: Identifiable, Codable", 1)

swift = """import Foundation
import CoreLocation
enum VTone: String, Codable { case travel, leisure, event, home }
""" + models + """
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
let data = try encoder.encode(VData.days)
FileHandle.standardOutput.write(data)
"""

with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "Export.swift"
    path.write_text(swift)
    result = subprocess.run(["swift", str(path)], check=True, capture_output=True)

days = json.loads(result.stdout)
for day in days:
    for index, event in enumerate(day["events"]):
        event["id"] = f"{day['id']}.{index}"
        event.pop("ref", None)
        event.pop("mapsQuery", None)
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(json.dumps(days, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
print(f"Exported {len(days)} days to {OUTPUT}")
