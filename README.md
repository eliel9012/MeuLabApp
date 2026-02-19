# MeuLab App

App SwiftUI para iOS/iPadOS que monitora em tempo real os serviços do ambiente MeuLab (ADS-B, ACARS, satélite, sistema, rádio e clima).

## Visão geral

- Tabs principais: `ADS-B`, `Radar`, `ACARS`, `Satélite`, `Sistema`, `Rádio` e `Clima`
- Dados vindos de `https://app.meulab.fun` e feed de aeronaves próximas via `https://voa.meulab.fun`
- Suporte a push notifications com navegação automática para a aba relacionada ao alerta
- Token de API carregado em runtime (sem segredo hardcoded no código)

## Screenshots

| | | |
|---|---|---|
| ![ADS-B](Screenshots/apple-silicon/adsb.png)<br><sub>ADS-B: tráfego aéreo em tempo real</sub> | ![Alertas](Screenshots/apple-silicon/alerts.png)<br><sub>Alertas e eventos recebidos</sub> | ![Mapa](Screenshots/apple-silicon/map.png)<br><sub>Radar/Mapa com aeronaves</sub> |
| ![Rádio](Screenshots/apple-silicon/radio.png)<br><sub>Player da rádio com now playing</sub> | ![Satélite](Screenshots/apple-silicon/satellite.png)<br><sub>Imagens Meteor via SatDump</sub> | ![Sistema](Screenshots/apple-silicon/system.png)<br><sub>Métricas de CPU, RAM e disco</sub> |
| ![Clima](Screenshots/apple-silicon/weather.png)<br><sub>Condições atuais e previsão</sub> |  |  |

## Requisitos

- Xcode 15+
- iOS/iPadOS 17+
- Swift 5.9+

## Setup rápido

1. Abra `MeuLabApp.xcodeproj` no Xcode.
2. Crie `MeuLabApp/Resources/Secrets.plist` com base em `MeuLabApp/Resources/Secrets.plist.example`.
3. Preencha o token:

```xml
<key>API_TOKEN</key>
<string>SEU_TOKEN_AQUI</string>
```

4. Em `Signing & Capabilities`, configure seu Team.
5. Rode no simulador ou dispositivo (`⌘R`).

## Configuração de segredos

O app busca o token nesta ordem:

1. `Info.plist` (`API_TOKEN`)
2. `Secrets.plist` no bundle (`API_TOKEN`)

Se não houver token, endpoints protegidos retornam `401`.

## Arquitetura (código atual)

- `MeuLabApp/MeuLabApp.swift`: bootstrap do app e integração com notificações
- `MeuLabApp/ContentView.swift`: `TabView` principal e roteamento entre abas
- `MeuLabApp/Services/APIService.swift`: cliente HTTP e mapeamento de endpoints
- `MeuLabApp/Services/PushNotificationManager.swift`: permissões APNs, token e categorias
- `MeuLabApp/Services/AudioPlayer.swift`: player de rádio
- `MeuLabApp/Services/LocationManager.swift`: localização para funcionalidades de mapa/alertas
- `MeuLabApp/ViewModels/AppState.swift`: estado compartilhado da aplicação
- `MeuLabApp/Views/Tabs/*.swift`: telas funcionais por domínio

## Endpoints usados pelo app

| Endpoint | Uso |
|---|---|
| `/api/adsb/summary` | resumo ADS-B |
| `/api/adsb/aircraft` | lista de aeronaves |
| `/api/acars/summary` | resumo ACARS |
| `/api/acars/messages` | últimas mensagens ACARS |
| `/api/acars/hourly` | estatísticas horárias ACARS |
| `/api/acars/search` | busca de mensagens ACARS |
| `/api/system/status` | status do sistema |
| `/api/radio/now-playing` | música/programa atual |
| `/api/weather/current` | clima atual |
| `/api/satdump/last/images` | últimas imagens de satélite |
| `/api/satdump/passes` | passes de satélite |
| `/api/satdump/image` | imagem individual de satélite |
| `/notifications/register` | registro de token push |
| `/notifications/unregister` | remoção de token push |

## Push notifications

Para habilitar ponta a ponta:

1. Ative `Push Notifications` e `Background Modes > remote-notification` no target.
2. Configure APNs no Apple Developer.
3. Garanta que o backend aceite `register/unregister` com token válido.

## Licença

Uso pessoal - MeuLab.fun.
