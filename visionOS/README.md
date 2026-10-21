# MeuLab Vision

App nativo visionOS. A central mostra ADS-B, Sistema, Infraestrutura, Rádio, Clima e ACARS com dados reais. Ao abrir ADS-B, o radar surge como volume RealityKit tridimensional ao lado da janela; o botão **Radar 3D** permite fechá-lo e reabri-lo. A ficha da aeronave busca fotos no PlaneSpotters (com fallback OpenSky) e dados de voo no FlightAware via backend MeuLab. Ícone do iPhone também usado no app visionOS. O app iOS original permanece no seu alvo atual.

## Abrir

1. Tenha Xcode 27 e o runtime do Apple Vision Pro instalados.
2. Coloque o `Secrets.plist` existente do MeuLab na raiz do repositório. Ele precisa conter `API_BASE_URL` e `API_TOKEN`. O arquivo é ignorado pelo Git e copiado para o bundle apenas durante o build.
3. Abra `MeuLabVision.xcodeproj`, selecione o esquema `MeuLabVision` e execute no simulador Apple Vision Pro.

Para recriar o projeto após mudar `project.yml`, execute `xcodegen generate --spec visionOS/project.yml` na raiz do repositório.

O radar consulta `https://radar.meulab.fun/data/aircraft.json` automaticamente a cada 3 segundos quando conectado. A mesa mostra mapa do MapKit centrado no receptor de Franca, com cidades vizinhas. Pinça e arrasto na mesa ou na alça frontal movem mapa, aeronaves e rótulos juntos nos eixos X e Y; limites de 18 cm na horizontal e 25 cm na vertical. MapKit não requer token. Aeronaves usam modelos 3D procedurais de jato ou turboélice, com asas afiladas, cabine, janelas, motores e detalhes próprios. Os outros painéis usam a API configurada no `Secrets.plist`. A tela mostra erro de conexão quando a fonte falha e preserva as últimas observações recebidas. Nenhum dado fictício é carregado.

O botão **Mapa interativo** abre um mapa MapKit ligado ao radar 3D: seleção da aeronave, estilos padrão/satélite/híbrido, aeroportos, rótulos, posição de Franca, seguimento e trilhas da sessão. A trilha da aeronave selecionada também aparece no volume 3D. As trilhas são formadas somente por posições ADS-B recebidas após abrir o app; não há histórico inventado.

O botão **Buscar voos** abre a busca de número/matrícula/ICAO. Resultados locais vêm do ADS-B; consulta por identificador e painéis de partidas/chegadas (GRU, CGH, VCP, RAO) vêm do FlightAware via backend MeuLab. Há filtro de rota por códigos IATA/ICAO a partir da primeira página do painel de origem ou destino. Um voo só pode ser mostrado no radar espacial quando sua aeronave também estiver sendo captada pelo receptor local. Os painéis são atualizados a cada 60 segundos enquanto a janela está aberta. A busca antiga `/api/flights/search` do iPhone não é usada aqui porque aquele endpoint está marcado como mock.
