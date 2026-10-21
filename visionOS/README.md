# MeuLab Vision

App nativo visionOS. A central mostra ADS-B, Sistema, Infraestrutura, Rádio, Clima e ACARS com dados reais. Ao abrir ADS-B, o radar surge como volume RealityKit tridimensional ao lado da janela; o botão **Radar 3D** permite fechá-lo e reabri-lo. O app iOS original permanece no seu alvo atual.

## Abrir

1. Tenha Xcode 27 e o runtime do Apple Vision Pro instalados.
2. Coloque o `Secrets.plist` existente do MeuLab na raiz do repositório. Ele precisa conter `API_BASE_URL` e `API_TOKEN`. O arquivo é ignorado pelo Git e copiado para o bundle apenas durante o build.
3. Abra `MeuLabVision.xcodeproj`, selecione o esquema `MeuLabVision` e execute no simulador Apple Vision Pro.

Para recriar o projeto após mudar `project.yml`, execute `xcodegen generate --spec visionOS/project.yml` na raiz do repositório.

O radar consulta `https://radar.meulab.fun/data/aircraft.json`. Os outros painéis usam a API configurada no `Secrets.plist`. A tela mostra erro de conexão quando a fonte falha e preserva as últimas observações recebidas. Nenhum dado fictício é carregado.
