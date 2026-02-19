# MeuLab App

App SwiftUI para iOS/iPadOS que monitora dados do servidor Raspberry Pi em tempo real.

## Setup rapido

1. Copie a pasta `MeuLabApp` para seu Mac
2. Crie `MeuLabApp/Resources/Secrets.plist` a partir do exemplo
3. Abra `MeuLabApp.xcodeproj` no Xcode e rode

## Funcionalidades

- **ADS-B**: Rastreamento de aeronaves em tempo real
- **Satélite**: Imagens do Meteor M2-x via SatDump
- **Sistema**: Status do Raspberry Pi (CPU, RAM, disco, Wi-Fi)
- **Rádio**: Player da Diário FM com Now Playing no Control Center
- **Clima**: Previsão do tempo para Franca, SP

## Screenshots

### ADS-B
![Tela ADS-B](Screenshots/apple-silicon/adsb.png)
_Visão geral do tráfego aéreo em tempo real._

### Alertas
![Tela de alertas](Screenshots/apple-silicon/alerts.png)
_Feed de notificações e eventos recentes do sistema._

### Mapa
![Tela de mapa](Screenshots/apple-silicon/map.png)
_Mapa com posições de aeronaves e contexto geográfico._

### Rádio
![Tela de rádio](Screenshots/apple-silicon/radio.png)
_Player da Diário FM com status de reprodução._

### Satélite
![Tela de satélite](Screenshots/apple-silicon/satellite.png)
_Imagens Meteor e monitoramento de recepção SatDump._

### Sistema
![Tela de sistema](Screenshots/apple-silicon/system.png)
_Métricas de CPU, memória, disco e saúde geral._

### Clima
![Tela de clima](Screenshots/apple-silicon/weather.png)
_Condições atuais e previsão para Franca, SP._

## Requisitos

- Xcode 15.0+
- iOS 17.0+ / iPadOS 17.0+
- Swift 5.9+

## Instalação

1. Copie a pasta `MeuLabApp` para seu Mac
2. Abra `MeuLabApp.xcodeproj` no Xcode
3. Configure o Team de desenvolvimento em Signing & Capabilities
4. Conecte seu iPhone/iPad ou selecione um simulador
5. Build e Run (⌘R)

## Configuração

O app já está configurado para conectar à API em `https://app.meulab.fun`

### Token de API

O token não fica no código. Configure via `Info.plist` (chave `API_TOKEN`) ou crie
um arquivo `Secrets.plist` no bundle com o conteúdo do exemplo
`MeuLabApp/Resources/Secrets.plist.example`:

```xml
<key>API_TOKEN</key>
<string>SEU_TOKEN_AQUI</string>
```

## Estrutura do Projeto

```
MeuLabApp/
├── MeuLabApp.swift          # Entry point
├── ContentView.swift        # TabView principal
├── Info.plist              # Configurações do app
├── Models/                 # Modelos de dados
│   ├── ADSBModels.swift
│   ├── SystemModels.swift
│   ├── RadioModels.swift
│   ├── WeatherModels.swift
│   └── SatelliteModels.swift
├── Services/               # Serviços
│   ├── APIService.swift    # Cliente da API
│   └── AudioPlayer.swift   # Player de streaming
├── ViewModels/             # Estado do app
│   └── AppState.swift
├── Views/                  # Interfaces
│   └── Tabs/
│       ├── ADSBView.swift
│       ├── SystemView.swift
│       ├── RadioView.swift
│       ├── WeatherView.swift
│       └── SatelliteView.swift
└── Resources/
    └── Assets.xcassets/
```

## API Endpoints

O app consome os seguintes endpoints:

| Endpoint | Descrição |
|----------|-----------|
| `/api/adsb/summary` | Resumo do tráfego aéreo |
| `/api/adsb/aircraft` | Lista de aeronaves |
| `/api/system/status` | Status do sistema |
| `/api/radio/now-playing` | Música tocando agora |
| `/api/weather/current` | Clima atual e previsão |
| `/api/satdump/last/images` | Últimas imagens de satélite |
| `/api/satdump/passes` | Lista de passes |
| `/api/satdump/image` | Serve imagem PNG |

## Características Técnicas

- **Refresh automático**: Dados atualizados a cada 250ms
- **Interface estável**: Updates condicionais para evitar "jitter"
- **Background audio**: Rádio continua tocando em background
- **Now Playing**: Metadados exibidos no Control Center
- **iTunes integration**: Artwork e informações das músicas

## Notificações Push

Para ativar notificações push:

1. Configure um certificado APNs no Apple Developer Portal
2. Adicione o capability "Push Notifications" no Xcode
3. Configure o servidor para enviar notificações via APNs

## Licença

Uso pessoal - MeuLab.fun
