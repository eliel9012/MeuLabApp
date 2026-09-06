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

## Fase 4 — validação da migração

- Build iOS genérico e build iOS Simulator: **BUILD SUCCEEDED**.
- Quatro testes XCTest hospedados no app real, iPhone 17 Pro / iOS 26.5: **TEST SUCCEEDED**, zero falhas. Cobrem isolamento rádio/aeronaves, estado operacional ignorado, reconstrução dos caches via `didSet` e bindings OpenSky compartilhados nos dois sentidos.
- Auditoria estrutural verifica os 123 membros, ausência dos wrappers antigos e presença dos seis bindings.
- Runner gera cópia temporária do projeto com target XCTest; o projeto de produção não muda.
- iPhone físico foi listado, mas a conexão de desenvolvimento falhou (`A connection to this device could not be established`, `ddiServicesAvailable: false`). Sem comparação confiável de CPU/Energy no device.

Reproduzir testes (substituir UUID e diretório de trabalho):

```sh
python3 scripts/run_observation_tests.py \
  --destination 'platform=iOS Simulator,id=UUID' \
  --work-dir /caminho/para/work/observation-tests
```

## Fase 5 — radar

A view externa calcula uma projeção por avaliação de dados/filtros; câmera, seleção, sheets e histórico vivem na view interna e reutilizam a projeção. Uma passagem filtra aeronaves, e outra prepara lookup por ID, contadores e distribuição de altitude. Não há invalidação manual de cache nem lista inicialmente vazia aguardando `onAppear`.

`RadarTrailHistory` acumula mudanças e a view faz uma única atribuição quando necessário. `MKPolyline` é reconstruída somente quando os pontos daquela aeronave mudam. IDs de trilhas permanecem estáveis, em ordem determinística, até mudança de membros. Cor continua vindo da altitude atual; coleta com trilhas ocultas, remoção de aeronaves e teto de 60 pontos preservados.

Nove testes XCTest passaram no simulador: os quatro de Observation e cinco de radar. Equivalência contra algoritmos anteriores cobre 192 combinações de filtros/busca/altitude, 70 atualizações de histórico, remoção/entrada, aeronave parada, altitude alterada sem movimento, geometria por identidade e lote de 500 aeronaves. Isso verifica redução de trabalho redundante; não equivale a medição de CPU/Energy no device.
