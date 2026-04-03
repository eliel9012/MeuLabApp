#!/bin/bash
# Test analytics endpoints with period switching

import_json='import sys,json'

echo "=== SYSTEM 24h ==="
R1=$(curl -s 'http://localhost:8090/api/analytics/system?period=24h')
echo "$R1" | python3 -c "$import_json; d=json.load(sys.stdin); print(f'period={d[\"period\"]}, cpu_pts={len(d[\"cpu\"][\"dataPoints\"])}, cpu_avg={d[\"cpu\"][\"average\"]}, mem_avg={d[\"memory\"][\"averageUsage\"]}, temp={d[\"temperature\"][\"average\"]}')"

echo "=== SYSTEM 7d ==="
R2=$(curl -s 'http://localhost:8090/api/analytics/system?period=7d')
echo "$R2" | python3 -c "$import_json; d=json.load(sys.stdin); print(f'period={d[\"period\"]}, cpu_pts={len(d[\"cpu\"][\"dataPoints\"])}, cpu_avg={d[\"cpu\"][\"average\"]}, mem_avg={d[\"memory\"][\"averageUsage\"]}, temp={d[\"temperature\"][\"average\"]}')"

echo "=== SYSTEM 24h AGAIN (should match first) ==="
R3=$(curl -s 'http://localhost:8090/api/analytics/system?period=24h')
echo "$R3" | python3 -c "$import_json; d=json.load(sys.stdin); print(f'period={d[\"period\"]}, cpu_pts={len(d[\"cpu\"][\"dataPoints\"])}, cpu_avg={d[\"cpu\"][\"average\"]}, mem_avg={d[\"memory\"][\"averageUsage\"]}, temp={d[\"temperature\"][\"average\"]}')"

echo ""
echo "=== ADSB 24h ==="
curl -s 'http://localhost:8090/api/analytics/adsb?period=24h' | python3 -c "$import_json; d=json.load(sys.stdin); print(f'period={d[\"period\"]}, flights={d[\"totalFlights\"]}, hourly_pts={len(d[\"hourlyStats\"])}, topModels={len(d.get(\"topModels\",[]))}')"

echo "=== ADSB 7d ==="
curl -s 'http://localhost:8090/api/analytics/adsb?period=7d' | python3 -c "$import_json; d=json.load(sys.stdin); print(f'period={d[\"period\"]}, flights={d[\"totalFlights\"]}, hourly_pts={len(d[\"hourlyStats\"])}, topModels={len(d.get(\"topModels\",[]))}')"

echo "=== ADSB 24h AGAIN (should match first) ==="
curl -s 'http://localhost:8090/api/analytics/adsb?period=24h' | python3 -c "$import_json; d=json.load(sys.stdin); print(f'period={d[\"period\"]}, flights={d[\"totalFlights\"]}, hourly_pts={len(d[\"hourlyStats\"])}, topModels={len(d.get(\"topModels\",[]))}')"

echo ""
echo "=== SATELLITE 24h ==="
curl -s 'http://localhost:8090/api/analytics/satellite?period=24h' | python3 -c "$import_json; d=json.load(sys.stdin); print(f'period={d[\"period\"]}, passes={d[\"totalPasses\"]}, avg_elev={d[\"stats\"][\"averageElevation\"]}')"

echo "=== SATELLITE 7d ==="
curl -s 'http://localhost:8090/api/analytics/satellite?period=7d' | python3 -c "$import_json; d=json.load(sys.stdin); print(f'period={d[\"period\"]}, passes={d[\"totalPasses\"]}, avg_elev={d[\"stats\"][\"averageElevation\"]}')"

echo ""
echo "=== ADSB HISTORY FILE CHECK ==="
python3 << 'PYEOF'
import json
h = json.load(open('/home/pi/adsb_history.json'))
print("Keys:", list(h.keys()))
ms = h.get("models_seen", {})
print(f"models_seen ({len(ms)} entries):", dict(list(ms.items())[:5]))
rt = h.get("routes", {})
print(f"routes ({len(rt)} entries):", dict(list(rt.items())[:5]))
dp = h.get("daily_peaks", {})
print(f"daily_peaks ({len(dp)} days):", list(dp.keys())[:5])
PYEOF
echo ""
echo "=== DONE ==="
