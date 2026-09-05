# Migração de AppState e desempenho do radar

## Fase 1 — referência inicial

- Branch: `codex/ia-dashboard-weather`.
- Xcode 26.6 (17F113); Swift 5; target principal iOS 26.0.
- `xcodebuild -scheme MeuLabApp -destination 'generic/platform=iOS' build`: **BUILD SUCCEEDED** antes das edições.
- Inventário: 63 propriedades `@Published`; 60 propriedades internas (34 mutáveis e 26 constantes) pertencem a `AppState`. Os demais membros do arquivo pertencem a outros tipos.
- Ambiente: 31 declarações em 25 arquivos, 9 injeções de instância, 21 previews e 6 bindings em 5 escopos.
- Referência informada pelo usuário: CPU 25%, Energy Impact High, oscilação próxima de 1 Hz. Não é uma medição reproduzida pelo agente.
- Alterações locais anteriores foram inventariadas e copiadas para backup fora do repositório. Não fazem parte dos commits desta migração.

## Escopo e invariantes

Migrar somente `AppState`; preservar `@MainActor`, assinaturas, modelos, `didSet`, intervalos e lógica de refresh. Otimizar apenas processamento derivado do radar e publicação das trilhas, preservando filtros, seleção, cores, histórico de até 60 pontos e coleta de curso com trilhas ocultas.

## Validação prevista

Build iOS em cada marco compilável; teste de isolamento de Observation e bindings; teste de equivalência do filtro e histórico do radar; conferência final do diff. Medições de CPU/Energy dependem de cenário e dispositivo comparáveis; não inferir ganho percentual de testes sintéticos.

## Fase 2 — modelo

`AppState` usa `@Observable` e mantém `@MainActor`. Todos os 63 `@Published` removidos. Auditoria individual em `appstate-observation-audit.csv`: 123 membros armazenados. As 60 propriedades internas recebem `@ObservationIgnored`; membros antes publicados sem consumidor visual também são ignorados. Constantes recebem anotação explícita para documentar escopo, embora a macro já ignore `let`.

`manualAirlineOverrides` alimenta normalização e reconstrução de caches; as views leem `aircraftList`/`adsbAirlines`. `activeTabRawValue` e `radarBoundingBox` alimentam somente controle de refresh. Esses membros não precisam de rastreamento visual. `didSet`, acesso e lógica de refresh preservados. Commit intermediário depende da fase 3 para compilar consumidores.

## Fase 3 — views e bindings

31 consumidores em 25 arquivos usam `@Environment(AppState.self)`. Instância principal usa `@State`; 9 reinjeções e 21 previews usam `.environment`. Os 6 toggles mantêm bindings com `@Bindable` local em cinco escopos: `ADSBView.body`, `trafficScopeBar`, `MapView.statsOverlay`, `MapSettingsSheet.body` e `radarSettingsSheet`. Build iOS genérico após migração: **BUILD SUCCEEDED**.
