#!/bin/bash
# Script de teste da API MeuLab
# Uso: ./test_api.sh

API_URL="https://app.meulab.fun"
TOKEN="${MEULAB_API_TOKEN:-}"

if [ -z "$TOKEN" ]; then
  echo "Defina MEULAB_API_TOKEN antes de executar."
  exit 1
fi

echo "🔍 Testando API MeuLab..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para testar endpoint
test_endpoint() {
    local name=$1
    local endpoint=$2
    local expected=$3
    
    echo -n "Testing $name... "
    
    response=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN" "$API_URL$endpoint")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ OK${NC} (HTTP $http_code)"
        if [ ! -z "$expected" ]; then
            echo "$body" | python3 -m json.tool | grep -i "$expected" | head -3 | sed 's/^/  /'
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (HTTP $http_code)"
        echo "$body" | head -3 | sed 's/^/  /'
    fi
    echo ""
}

# Teste 1: Health Check
echo "1️⃣  Health Check"
test_endpoint "Health" "/health" ""

# Teste 2: ACARS Summary
echo "2️⃣  ACARS Summary"
test_endpoint "ACARS Summary" "/api/acars/summary" "messages"

# Teste 3: ACARS Messages
echo "3️⃣  ACARS Messages"
test_endpoint "ACARS Messages" "/api/acars/messages?limit=3" "flight"

# Teste 4: ACARS Hourly
echo "4️⃣  ACARS Hourly Stats"
test_endpoint "ACARS Hourly" "/api/acars/hourly" "hour"

# Teste 5: ADS-B Summary
echo "5️⃣  ADS-B Summary"
test_endpoint "ADS-B Summary" "/api/adsb/summary" "movement"

# Teste 6: ADS-B Aircraft
echo "6️⃣  ADS-B Aircraft List"
test_endpoint "Aircraft List" "/api/adsb/aircraft?limit=5" "callsign"

# Teste 7: ADS-B History
echo "7️⃣  ADS-B History"
test_endpoint "ADS-B History" "/api/adsb/history" "days"

# Teste 8: System Status
echo "8️⃣  System Status"
test_endpoint "System Status" "/api/system/status" "uptime"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Teste detalhado de Movement Data:"
echo ""

# Teste detalhado do movimento
movement_data=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_URL/api/adsb/summary" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'movement' in data:
    m = data['movement']
    print(f\"  Subindo (climbing):   {m.get('climbing', 'N/A')} aeronaves\")
    print(f\"  Descendo (descending): {m.get('descending', 'N/A')} aeronaves\")
    print(f\"  Cruzeiro (cruising):   {m.get('cruising', 'N/A')} aeronaves\")
    print(f\"  Total no ar:           {data.get('total_now', 'N/A')} aeronaves\")
else:
    print('  ❌ Campo movement não encontrado!')
")

echo "$movement_data"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Testes concluídos!"
echo ""
echo "Se todos os testes passaram mas o app não mostra dados:"
echo "  1. Verifique se o token no app está correto"
echo "  2. Limpe o cache do app"
echo "  3. Rebuild o projeto no Xcode"
echo "  4. Verifique os logs do Xcode para erros"
