# Arquitetura Refatorada do MeuLabApp

## 📁 Estrutura de Pastas

```
MeuLabApp/
├── App/                    # Configuração da aplicação
│   ├── MeuLabApp.swift     # Entry point e App Delegate
│   └── AppImports.swift    # Índice de imports
│
├── Core/                   # Componentes principais e infraestrutura
│   ├── Networking/         # APIs e networking
│   │   ├── APIServiceProtocol.swift
│   │   ├── APIService.swift
│   │   └── APIError.swift
│   ├── Services/          # Serviços auxiliares
│   │   ├── AudioPlayer.swift
│   │   ├── LocationManager.swift
│   │   └── PushNotificationManager.swift
│   └── Utils/             # Utilitários
│       └── Logger.swift
│
├── Extensions/            # Extensões de tipos
│   ├── Double+Conversions.swift
│   └── ... (outras extensões)
│
├── Modules/              # Features da aplicação (por domínio)
│   ├── ADSB/
│   │   ├── ADSBStateModule.swift
│   │   └── Models/ (reutiliza Models globais)
│   ├── ACARS/
│   │   ├── ACARSStateModule.swift
│   │   └── ...
│   ├── System/
│   │   ├── SystemStateModule.swift
│   │   └── ...
│   ├── Radio/
│   │   ├── RadioStateModule.swift
│   │   └── ...
│   ├── Weather/
│   │   ├── WeatherStateModule.swift
│   │   └── ...
│   └── Satellite/
│       ├── SatelliteStateModule.swift
│       └── ...
│
├── Views/                # UI Components
│   ├── Components/
│   ├── Tabs/
│   └── ...
│
├── ViewModels/           # State management
│   └── AppState.swift    # Orquestrador de módulos
│
├── Models/               # Modelos de dados (compartilhados)
│   ├── ADSBModels.swift
│   ├── ACARSModels.swift
│   └── ...
│
└── Resources/            # Assets e configurações
    ├── Assets.xcassets/
    └── Secrets.plist.example
```

## 🔄 Fluxo de Dados

```
MeuLabApp.swift (Entry Point)
    ↓
AppState (Orquestrador de Módulos)
    ├── ADSBStateModule
    ├── ACARSStateModule
    ├── SystemStateModule
    ├── RadioStateModule
    ├── WeatherStateModule
    └── SatelliteStateModule
         ↓
    APIService (implementa APIServiceProtocol)
         ↓
    Serviços: Logger, AudioPlayer, LocationManager, etc.
```

## 🎯 Principais Melhorias

### 1. **Modularização**
- Cada feature tem seu próprio `StateModule`
- Separação clara de responsabilidades
- Facilita testes e manutenção

### 2. **Logging Centralizado**
```swift
Logger.info("Mensagem informativa")
Logger.warning("Aviso")
Logger.error("Erro")
Logger.debug("Debug")
Logger.critical("Crítico")
```

### 3. **Tratamento de Erros Melhorado**
- `APIError` com `recoverySuggestion`
- Conversão automática de erros genéricos
- Better error categorization

### 4. **Protocol-based API**
- `APIServiceProtocol` permite mocks para testes
- Facilita trocas de implementação
- Melhor injeção de dependência

### 5. **Compatibilidade Preservada**
- `AppState` mantém propriedades antigas
- Código existente continua funcionando
- Migração gradual possível

## 🚀 Como Usar

### Acessar um módulo:
```swift
@EnvironmentObject var appState: AppState

// Acesso aos módulos
appState.adsb.summary
appState.acars.messages
appState.system.status
appState.radio.nowPlaying
appState.weather.weather_data
appState.satellite.passes
```

### Usar o Logger:
```swift
Logger.info("Iniciando refresh de dados")
Logger.logRequest(method: "GET", url: "/api/adsb/summary")
Logger.logResponse(statusCode: 200, url: "/api/adsb/summary", duration: 0.152)
Logger.logError(error, context: "ADSB Refresh")
```

### Para testes:
```swift
// Criar mock
class MockAPIService: APIServiceProtocol {
    // Implementar protocol
}

// Usar em AppState
let appState = AppState(api: MockAPIService())
```

## 📊 Refresh Strategy

- **Intervalo anterior**: 250ms (muito agressivo)
- **Intervalo atual**: 2s (balanceado)
- **Personalizar**:
  ```swift
  private let refreshInterval: TimeInterval = 5 // 5 segundos
  ```

## 🔧 Próximos Passos

1. ✅ Reorganizar estrutura de pastas
2. ✅ Criar Protocol para APIService
3. ✅ Melhorar tratamento de erros
4. ✅ Adicionar logging centralizado
5. ✅ Modularizar AppState
6. ⏳ Implementar pull-to-refresh
7. ⏳ Adicionar lazy loading para listas
8. ⏳ Criar sistema de estado unificado para Views
9. ⏳ Adicionar cache persistente

## 📝 Migração de Código Legado

### Antes:
```swift
let api = APIService.shared
try await api.fetchADSBSummary()
```

### Depois:
```swift
@EnvironmentObject var appState: AppState
let summary = appState.adsb.summary
```

Ou mantenha a compatibilidade:
```swift
let summary = appState.adsbSummary // Propriedade legacy
```
