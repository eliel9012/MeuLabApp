#!/bin/bash
# Checagem do padrão Liquid Glass (guia da Apple): vidro só na navegação/controles.
# ERRO: fundo próprio em barras/sheets; vidro em conteúdo sem marcação.
# AVISO: botões de ação ainda em .bordered/.borderedProminent.
# Para vidro legítimo sobre conteúdo (overlay de mapa, player, HUD) marque a linha com:  // glass: floating
cd "$(dirname "$0")/.." || exit 2
DIRS="MeuLabApp"
EXCL="SatelliteView.swift|LiquidGlass\+Modifiers.swift"
err=0
report() { # $1=nível $2=descrição $3=regex
  local hits
  hits=$(grep -rnE "$3" --include='*.swift' $DIRS | grep -vE "$EXCL" | grep -v "glass: floating")
  if [ -n "$hits" ]; then
    echo "[$1] $2 ($(echo "$hits" | wc -l | tr -d ' '))"
    echo "$hits" | sed -E 's/^([^:]+:[0-9]+):\s*/  \1  /' | cut -c1-160
    [ "$1" = ERRO ] && err=1
  fi
}
report ERRO  "Fundo customizado em barra/sheet" 'toolbarBackground\(|UINavigationBarAppearance|UITabBarAppearance|presentationBackground\('
report ERRO  "glassCard em conteúdo (use contentCard ou marque // glass: floating)" '\.glassCard\('
report ERRO  "glassEffect direto (use glassControl/glassCard ou marque // glass: floating)" '\.glassEffect\('
report AVISO "Botão de ação sem estilo glass" '\.buttonStyle\(\.(bordered|borderedProminent)\)'
[ $err = 0 ] && echo "OK: nenhum erro de Liquid Glass." 
exit $err
