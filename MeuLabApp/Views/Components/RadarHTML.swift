import Foundation

enum RadarHTML {
    static var content: String {
        let envJWT = ProcessInfo.processInfo.environment["MEULAB_MAPKIT_JWT"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let plistJWT = (Bundle.main.object(forInfoDictionaryKey: "MEULAB_MAPKIT_JWT") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let jwt = envJWT?.isEmpty == false ? envJWT! : (plistJWT ?? "")
        return rawContent.replacingOccurrences(of: "__MEULAB_MAPKIT_JWT__", with: jwt)
    }

    private static let rawContent = #"""
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover" />
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
  <meta name="theme-color" content="#0a0c10" />
  <title>Radar ADS-B</title>
  <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>✈️</text></svg>">
  <style>
	:root {
	  --bg: #0a0c10;
	  --panel: #12161c;
	  --panel-border: #1e2632;
	  --text: #e9edf1;
	  --muted: #6b7785;
	  --accent: #3b9eff;
	  --ok: #22c55e;
	  --warn: #f59e0b;
	  --bad: #ef4444;
	  --military: #a855f7;
	  --shadow: 0 8px 32px rgba(0,0,0,.5);
	  --safe-top: env(safe-area-inset-top, 0);
	  --safe-bottom: env(safe-area-inset-bottom, 0);
	  --safe-left: env(safe-area-inset-left, 0);
	  --safe-right: env(safe-area-inset-right, 0);
	}
	[data-theme="light"] {
	  --bg: #f0f2f5;
	  --panel: #ffffff;
	  --panel-border: #d1d5db;
	  --text: #1f2937;
	  --muted: #6b7280;
	}
	* { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
	html, body { height: 100%; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif; background: var(--bg); color: var(--text); overflow: hidden; touch-action: manipulation; }
	.app { display: grid; grid-template-rows: auto 1fr auto; height: 100%; padding-top: var(--safe-top); padding-bottom: var(--safe-bottom); }

	header { display: flex; justify-content: space-between; align-items: center; padding: 8px 12px; padding-left: calc(12px + var(--safe-left)); padding-right: calc(12px + var(--safe-right)); background: linear-gradient(180deg, var(--panel), var(--bg)); border-bottom: 1px solid var(--panel-border); z-index: 100; flex-wrap: wrap; gap: 6px; }
	.header-left { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
	.header-left h1 { font-size: 13px; font-weight: 600; letter-spacing: .5px; background: linear-gradient(135deg, #fff, #a0aab8); -webkit-background-clip: text; -webkit-text-fill-color: transparent; cursor: pointer; }
	.header-controls { display: flex; gap: 4px; }
	.header-btn { width: 32px; height: 32px; border: 1px solid var(--panel-border); background: var(--panel); color: var(--text); border-radius: 8px; cursor: pointer; font-size: 14px; display: flex; align-items: center; justify-content: center; transition: all .2s; }
	.header-btn:hover, .header-btn.active { background: var(--accent); border-color: var(--accent); }
	.header-btn.alert { animation: pulse-alert 1s infinite; }
	@keyframes pulse-alert { 0%, 100% { background: var(--bad); } 50% { background: var(--panel); } }
	.map-type-toggle { display: flex; background: var(--panel); border-radius: 6px; overflow: hidden; border: 1px solid var(--panel-border); }
	.map-type-toggle button { padding: 5px 8px; border: none; background: transparent; color: var(--muted); font-size: 10px; cursor: pointer; transition: all .2s; }
	.map-type-toggle button.active { background: var(--accent); color: #fff; }
	.status { display: flex; align-items: center; gap: 8px; font-size: 10px; color: var(--muted); flex-wrap: wrap; }
	.status-item { display: flex; align-items: center; gap: 3px; }
	.status-item .value { color: var(--text); font-weight: 600; font-variant-numeric: tabular-nums; }
	.status-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--ok); animation: pulse 2s infinite; }
	.status-dot.offline { background: var(--bad); }
	.status-dot.cached { background: var(--warn); }
	@keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: .5; } }

	#map { width: 100%; height: 100%; position: relative; }
	#map:fullscreen, #map:-webkit-full-screen { width: 100vw; height: 100vh; }

	.panel { position: absolute; top: calc(52px + var(--safe-top)); left: calc(8px + var(--safe-left)); width: 240px; max-width: calc(100vw - 16px); background: rgba(18,22,28,.92); backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); border: 1px solid var(--panel-border); border-radius: 12px; padding: 10px; font-size: 11px; box-shadow: var(--shadow); z-index: 50; max-height: calc(100vh - 120px); overflow-y: auto; -webkit-overflow-scrolling: touch; transition: transform .3s, opacity .3s; }
	.panel.hidden { transform: translateX(-110%); opacity: 0; pointer-events: none; }
	.panel-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
	.panel-header h2 { font-size: 10px; text-transform: uppercase; letter-spacing: 1px; color: var(--muted); }
	.panel-tabs { display: flex; gap: 2px; margin-bottom: 8px; }
	.panel-tab { flex: 1; padding: 6px 4px; border: none; background: rgba(255,255,255,.05); color: var(--muted); font-size: 9px; cursor: pointer; border-radius: 4px; transition: all .2s; }
	.panel-tab.active { background: var(--accent); color: #fff; }
	.panel-section { display: none; }
	.panel-section.active { display: block; }
	.filter-group { margin-bottom: 6px; }
	.filter-group label { display: block; font-size: 9px; color: var(--muted); margin-bottom: 3px; text-transform: uppercase; letter-spacing: .5px; }
	.filter-group input, .filter-group select { width: 100%; padding: 8px; border-radius: 6px; border: 1px solid var(--panel-border); background: rgba(0,0,0,.3); color: var(--text); font-size: 12px; }
	.filter-group input:focus { outline: none; border-color: var(--accent); }
	.filter-row { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }
	.toggle-group { margin-top: 8px; padding-top: 8px; border-top: 1px solid var(--panel-border); }
	.toggle-item { display: flex; align-items: center; justify-content: space-between; padding: 6px 0; }
	.toggle-item span { font-size: 11px; }
	.toggle-switch { position: relative; width: 40px; height: 22px; }
	.toggle-switch input { opacity: 0; width: 0; height: 0; }
	.toggle-slider { position: absolute; cursor: pointer; inset: 0; background: var(--panel-border); border-radius: 22px; transition: .2s; }
	.toggle-slider:before { position: absolute; content: ""; height: 16px; width: 16px; left: 3px; bottom: 3px; background: #fff; border-radius: 50%; transition: .2s; }
	.toggle-switch input:checked + .toggle-slider { background: var(--accent); }
	.toggle-switch input:checked + .toggle-slider:before { transform: translateX(18px); }

	.stats-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 6px; margin-bottom: 8px; }
	.stat-card { background: rgba(0,0,0,.2); padding: 8px; border-radius: 6px; text-align: center; }
	.stat-value { font-size: 18px; font-weight: 700; font-variant-numeric: tabular-nums; }
	.stat-label { font-size: 9px; color: var(--muted); text-transform: uppercase; }
	.stat-card.highlight { border: 1px solid var(--accent); }

	.favorites-list { max-height: 150px; overflow-y: auto; }
	.fav-item { display: flex; justify-content: space-between; align-items: center; padding: 6px; background: rgba(0,0,0,.2); border-radius: 6px; margin-bottom: 4px; cursor: pointer; }
	.fav-item:hover { background: rgba(59,158,255,.2); }
	.fav-item .callsign { font-weight: 600; }
	.fav-item .fav-status { font-size: 9px; color: var(--muted); }
	.fav-remove { background: none; border: none; color: var(--bad); cursor: pointer; font-size: 14px; }

	.airport-marker { display: flex; flex-direction: column; align-items: center; }
	.airport-icon { font-size: 16px; }
	.airport-label { font-size: 9px; font-weight: 700; color: #fff; background: rgba(0,0,0,.6); padding: 1px 4px; border-radius: 3px; }

	.details { position: absolute; right: calc(8px + var(--safe-right)); top: calc(52px + var(--safe-top)); width: 280px; max-width: calc(100vw - 16px); background: rgba(18,22,28,.92); backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); border: 1px solid var(--panel-border); border-radius: 12px; padding: 12px; font-size: 11px; box-shadow: var(--shadow); z-index: 50; transition: transform .3s, opacity .3s; max-height: calc(100vh - 120px); overflow-y: auto; }
	.details.hidden { transform: translateX(110%); opacity: 0; pointer-events: none; }
	.details-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px; }
	.details-callsign { font-size: 18px; font-weight: 700; font-variant-numeric: tabular-nums; }
	.details-hex { font-size: 10px; color: var(--muted); font-family: monospace; }
	.details-badge { display: inline-block; padding: 3px 6px; border-radius: 4px; font-size: 10px; font-weight: 600; background: var(--accent); color: #fff; }
	.details-badge.military { background: var(--military); }
	.details-badge.emergency { background: var(--bad); animation: flash .5s infinite; }
	@keyframes flash { 0%, 100% { opacity: 1; } 50% { opacity: .6; } }
	.details-photo { width: 100%; height: 80px; background: var(--panel); border-radius: 8px; margin: 8px 0; overflow: hidden; display: flex; align-items: center; justify-content: center; }
	.details-photo img { width: 100%; height: 100%; object-fit: cover; }
	.details-photo .placeholder { color: var(--muted); font-size: 24px; }
	.details-route { background: rgba(0,0,0,.2); padding: 8px; border-radius: 6px; margin-bottom: 8px; text-align: center; }
	.details-route .airports { font-size: 14px; font-weight: 600; }
	.details-route .arrow { color: var(--accent); margin: 0 8px; }
	.details-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; margin: 10px 0; }
	.details-stat { background: rgba(0,0,0,.2); padding: 8px; border-radius: 6px; text-align: center; }
	.details-stat-label { font-size: 8px; color: var(--muted); text-transform: uppercase; }
	.details-stat-value { font-size: 13px; font-weight: 600; font-variant-numeric: tabular-nums; margin-top: 2px; }
	.details-stat-value.climbing { color: var(--ok); }
	.details-stat-value.descending { color: var(--warn); }

	.altitude-chart { height: 50px; background: rgba(0,0,0,.2); border-radius: 6px; margin: 8px 0; padding: 4px; position: relative; }
	.altitude-chart canvas { width: 100%; height: 100%; }
	.altitude-chart-label { position: absolute; top: 2px; left: 6px; font-size: 8px; color: var(--muted); }

	.details-actions { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; margin-top: 10px; }
	.details-actions button { padding: 8px 4px; border: 1px solid var(--panel-border); background: rgba(0,0,0,.2); color: var(--text); border-radius: 6px; cursor: pointer; font-size: 10px; transition: all .2s; }
	.details-actions button:hover, .details-actions button.active { background: var(--accent); border-color: var(--accent); }
	.details-meta { font-size: 9px; color: var(--muted); margin-top: 8px; padding-top: 8px; border-top: 1px solid var(--panel-border); }

	.bottom-bar { display: flex; align-items: center; gap: 8px; padding: 6px 12px; padding-left: calc(12px + var(--safe-left)); padding-right: calc(12px + var(--safe-right)); background: var(--panel); border-top: 1px solid var(--panel-border); flex-wrap: wrap; }
	.altitude-bar-title { font-size: 9px; color: var(--muted); text-transform: uppercase; }
	.altitude-bar-segments { display: flex; flex: 1; min-width: 80px; height: 6px; border-radius: 3px; overflow: hidden; background: rgba(255,255,255,.1); }
	.altitude-segment { height: 100%; transition: width .3s; }
	.altitude-segment.ground { background: #6b7785; }
	.altitude-segment.low { background: var(--ok); }
	.altitude-segment.medium { background: var(--accent); }
	.altitude-segment.high { background: var(--warn); }
	.altitude-segment.cruise { background: var(--bad); }
	.msg-rate { font-size: 10px; color: var(--muted); }
	.msg-rate .value { color: var(--ok); font-weight: 600; }

	.replay-controls { position: absolute; bottom: calc(50px + var(--safe-bottom)); left: 50%; transform: translateX(-50%); background: rgba(18,22,28,.92); backdrop-filter: blur(16px); border: 1px solid var(--panel-border); border-radius: 20px; padding: 8px 16px; display: none; align-items: center; gap: 12px; z-index: 60; }
	.replay-controls.visible { display: flex; }
	.replay-controls button { width: 32px; height: 32px; border: none; background: var(--panel-border); color: var(--text); border-radius: 50%; cursor: pointer; font-size: 14px; }
	.replay-controls button:hover { background: var(--accent); }
	.replay-slider { width: 200px; }
	.replay-time { font-size: 11px; font-variant-numeric: tabular-nums; }

	.geofence-alert { position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: var(--bad); color: #fff; padding: 20px 30px; border-radius: 12px; font-size: 14px; font-weight: 600; z-index: 200; display: none; text-align: center; box-shadow: 0 0 40px rgba(239,68,68,.5); }
	.geofence-alert.visible { display: block; animation: shake .5s; }
	@keyframes shake { 0%, 100% { transform: translate(-50%, -50%); } 25% { transform: translate(-48%, -50%); } 75% { transform: translate(-52%, -50%); } }

	.metar-popup { position: absolute; background: rgba(18,22,28,.95); border: 1px solid var(--panel-border); border-radius: 8px; padding: 10px; font-size: 10px; max-width: 250px; z-index: 100; display: none; }
	.metar-popup.visible { display: block; }
	.metar-popup h3 { font-size: 12px; margin-bottom: 6px; }
	.metar-popup .metar-raw { font-family: monospace; background: rgba(0,0,0,.3); padding: 6px; border-radius: 4px; word-break: break-all; margin-bottom: 6px; }
	.metar-popup .metar-decoded { color: var(--muted); }

	.receiver-marker { width: 16px; height: 16px; background: var(--accent); border-radius: 50%; animation: none; }
	@keyframes rpulse { 0%, 100% { transform: scale(1); opacity: 1; } 50% { transform: scale(1.5); opacity: .5; } }
	.aircraft-container { display: flex; flex-direction: column; align-items: center; cursor: pointer; }
	.aircraft-icon { font-size: 22px; text-shadow: 0 2px 4px rgba(0,0,0,.5); line-height: 1; }
	.aircraft-label { margin-top: 2px; padding: 1px 4px; background: rgba(0,0,0,.75); border-radius: 3px; font-size: 9px; font-weight: 600; color: #fff; white-space: nowrap; font-family: monospace; }
	.aircraft-container.selected .aircraft-icon { filter: drop-shadow(0 0 8px var(--accent)); }
	.aircraft-container.selected .aircraft-label { background: var(--accent); }
	.aircraft-container.military .aircraft-icon { filter: drop-shadow(0 0 6px var(--military)); }
	.aircraft-container.military .aircraft-label { background: var(--military); }
	.aircraft-container.emergency .aircraft-icon { filter: drop-shadow(0 0 8px var(--bad)); animation: eglow .5s infinite; }
	.aircraft-container.emergency .aircraft-label { background: var(--bad); }
	.aircraft-container.favorite .aircraft-label { border: 1px solid var(--warn); }
	.aircraft-container.opensky .aircraft-label { background: var(--warn); }
	.aircraft-container.opensky .aircraft-icon { filter: drop-shadow(0 0 6px var(--warn)); }
	@keyframes eglow { 0%, 100% { filter: drop-shadow(0 0 8px var(--bad)); } 50% { filter: drop-shadow(0 0 16px var(--bad)); } }

	.cache-banner { position: fixed; top: calc(46px + var(--safe-top)); left: 50%; transform: translateX(-50%); background: var(--warn); color: #000; padding: 4px 12px; border-radius: 12px; font-size: 10px; font-weight: 600; z-index: 200; display: none; }
	.cache-banner.visible { display: block; }

	.toast { position: fixed; bottom: calc(60px + var(--safe-bottom)); left: 50%; transform: translateX(-50%); background: var(--panel); border: 1px solid var(--panel-border); color: var(--text); padding: 10px 20px; border-radius: 20px; font-size: 12px; z-index: 200; display: none; }
	.toast.visible { display: block; animation: fadeInUp .3s; }
	@keyframes fadeInUp { from { opacity: 0; transform: translate(-50%, 20px); } to { opacity: 1; transform: translate(-50%, 0); } }

	.modal { position: fixed; inset: 0; background: rgba(0,0,0,.7); display: none; align-items: center; justify-content: center; z-index: 300; }
	.modal.visible { display: flex; }
	.modal-content { background: var(--panel); border: 1px solid var(--panel-border); border-radius: 16px; padding: 20px; max-width: 90%; width: 360px; }
	.modal-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; }
	.modal-header h3 { font-size: 16px; }
	.modal-close { background: none; border: none; color: var(--muted); font-size: 20px; cursor: pointer; }
	.modal-input { width: 100%; padding: 12px; border: 1px solid var(--panel-border); background: rgba(0,0,0,.3); color: var(--text); border-radius: 8px; font-size: 12px; margin-bottom: 12px; }
	.modal-btn { width: 100%; padding: 12px; border: none; background: var(--accent); color: #fff; border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer; }

	@media (max-width: 768px) {
	  .panel { width: calc(100% - 16px); left: 8px; max-height: 40vh; }
	  .details { width: calc(100% - 16px); left: 8px; right: auto; top: auto; bottom: calc(46px + var(--safe-bottom)); max-height: 50vh; }
	  .details.hidden { transform: translateY(110%); }
	  .replay-controls { width: calc(100% - 32px); }
	  .replay-slider { flex: 1; }
	}
	@media (min-width: 1024px) {
	  .panel { width: 280px; }
	  .details { width: 320px; }
	}
  </style>
  <script src="https://cdn.apple-mapkit.com/mk/5.x.x/mapkit.js"></script>
</head>
<body>
  <div class="app">
	<header>
	  <div class="header-left">
		<h1 id="title">Radar ADS-B</h1>
		<div class="map-type-toggle">
		  <button id="map-standard" class="active">Mapa</button>
		  <button id="map-satellite">Sat</button>
		  <button id="map-hybrid">Hib</button>
		</div>
		<div class="header-controls">
		  <button class="header-btn" id="btn-panel" title="Painel">☰</button>
		  <button class="header-btn" id="btn-theme" title="Tema">◐</button>
		  <button class="header-btn" id="btn-fullscreen" title="Fullscreen">⛶</button>
		  <button class="header-btn" id="btn-sound" title="Som">🔔</button>
		  <button class="header-btn" id="btn-replay" title="Replay">⏪</button>
		</div>
	  </div>
	  <div class="status">
		<div class="status-item"><div class="status-dot" id="status-dot"></div><span id="status-label">Ao vivo</span></div>
		<div class="status-item">✈️ <span class="value" id="status-count">0</span></div>
		<div class="status-item">📍 <span class="value" id="status-visible">0</span></div>
		<div class="status-item">🕐 <span class="value" id="status-time">--:--</span></div>
	  </div>
	</header>
	<div id="map"></div>
	<div class="bottom-bar">
	  <span class="altitude-bar-title">Alt</span>
	  <div class="altitude-bar-segments">
		<div class="altitude-segment ground" id="alt-ground"></div>
		<div class="altitude-segment low" id="alt-low"></div>
		<div class="altitude-segment medium" id="alt-medium"></div>
		<div class="altitude-segment high" id="alt-high"></div>
		<div class="altitude-segment cruise" id="alt-cruise"></div>
	  </div>
	  <div class="msg-rate">MSG: <span class="value" id="msg-rate">0</span>/s</div>
	</div>
  </div>

  <div class="panel hidden" id="panel">
	<div class="panel-tabs">
	  <button class="panel-tab active" data-tab="filters">Filtros</button>
	  <button class="panel-tab" data-tab="stats">Stats</button>
	  <button class="panel-tab" data-tab="favorites">Favs</button>
	  <button class="panel-tab" data-tab="settings">Config</button>
	</div>

	<div class="panel-section active" id="tab-filters">
	  <div class="filter-group">
		<label>Buscar</label>
		<input id="filter-text" type="text" placeholder="Callsign, Hex, Tipo..." autocomplete="off">
	  </div>
	  <div class="filter-row">
		<div class="filter-group"><label>Alt Min</label><input id="filter-alt-min" type="number" placeholder="0"></div>
		<div class="filter-group"><label>Alt Max</label><input id="filter-alt-max" type="number" placeholder="45000"></div>
	  </div>
	  <div class="filter-row">
		<div class="filter-group"><label>Vel Min</label><input id="filter-spd-min" type="number" placeholder="0"></div>
		<div class="filter-group"><label>Vel Max</label><input id="filter-spd-max" type="number" placeholder="650"></div>
	  </div>
	  <div class="toggle-group">
		<div class="toggle-item"><span>Trilhas</span><label class="toggle-switch"><input id="toggle-trails" type="checkbox" checked><span class="toggle-slider"></span></label></div>
		<div class="toggle-item"><span>Anéis</span><label class="toggle-switch"><input id="toggle-rings" type="checkbox"><span class="toggle-slider"></span></label></div>
		<div class="toggle-item"><span>Labels</span><label class="toggle-switch"><input id="toggle-labels" type="checkbox" checked><span class="toggle-slider"></span></label></div>
		<div class="toggle-item"><span>Militar</span><label class="toggle-switch"><input id="toggle-military" type="checkbox" checked><span class="toggle-slider"></span></label></div>
		<div class="toggle-item"><span>Aeroportos</span><label class="toggle-switch"><input id="toggle-airports" type="checkbox" checked><span class="toggle-slider"></span></label></div>
		<div class="toggle-item"><span>Previsão Rota</span><label class="toggle-switch"><input id="toggle-prediction" type="checkbox"><span class="toggle-slider"></span></label></div>
		<div class="toggle-item"><span>Dia/Noite</span><label class="toggle-switch"><input id="toggle-terminator" type="checkbox"><span class="toggle-slider"></span></label></div>
	  </div>
	</div>

	<div class="panel-section" id="tab-stats">
	  <div class="stats-grid">
		<div class="stat-card"><div class="stat-value" id="stat-total">0</div><div class="stat-label">Total Hoje</div></div>
		<div class="stat-card"><div class="stat-value" id="stat-max-alt">0</div><div class="stat-label">Alt Máx</div></div>
		<div class="stat-card"><div class="stat-value" id="stat-max-speed">0</div><div class="stat-label">Vel Máx</div></div>
		<div class="stat-card"><div class="stat-value" id="stat-military">0</div><div class="stat-label">Militares</div></div>
		<div class="stat-card highlight"><div class="stat-value" id="stat-closest">--</div><div class="stat-label">Mais Perto</div></div>
		<div class="stat-card"><div class="stat-value" id="stat-farthest">--</div><div class="stat-label">Mais Longe</div></div>
	  </div>
	  <div style="font-size:9px;color:var(--muted);margin-top:8px">
		<div>Atualizado: <span id="stat-update">--</span></div>
		<div>Uptime: <span id="stat-uptime">--</span></div>
	  </div>
	</div>

	<div class="panel-section" id="tab-favorites">
	  <div class="filter-group">
		<label>Adicionar por Hex/Callsign</label>
		<input id="fav-input" type="text" placeholder="E482C6 ou TAM3952">
	  </div>
	  <button style="width:100%;padding:8px;border:none;background:var(--accent);color:#fff;border-radius:6px;cursor:pointer;margin-bottom:8px" id="fav-add">+ Adicionar</button>
	  <div class="favorites-list" id="fav-list"></div>
	  <div class="toggle-group">
		<div class="toggle-item"><span>Alerta Favoritos</span><label class="toggle-switch"><input id="toggle-fav-alert" type="checkbox" checked><span class="toggle-slider"></span></label></div>
	  </div>
	</div>

	<div class="panel-section" id="tab-settings">
	  <div class="filter-group">
		<label>Geofence Raio (nm)</label>
		<input id="geofence-radius" type="number" placeholder="50" value="50">
	  </div>
	  <div class="toggle-group">
		<div class="toggle-item"><span>Geofence Ativo</span><label class="toggle-switch"><input id="toggle-geofence" type="checkbox"><span class="toggle-slider"></span></label></div>
		<div class="toggle-item"><span>Alerta Militar</span><label class="toggle-switch"><input id="toggle-mil-alert" type="checkbox" checked><span class="toggle-slider"></span></label></div>
		<div class="toggle-item"><span>Alerta Emergência</span><label class="toggle-switch"><input id="toggle-emerg-alert" type="checkbox" checked><span class="toggle-slider"></span></label></div>
	  </div>
	  <div style="margin-top:12px;padding-top:8px;border-top:1px solid var(--panel-border)">
		<div style="font-size:9px;color:var(--muted)">Receptor:</div>
		<div style="font-size:11px;font-family:monospace" id="receiver-info">--</div>
	  </div>
	</div>
  </div>

  <div class="details hidden" id="details">
	<div class="details-header">
	  <div>
		<div class="details-callsign" id="sel-callsign">--</div>
		<div class="details-hex" id="sel-hex">--</div>
	  </div>
	  <div>
		<span class="details-badge" id="sel-badge">--</span>
		<button class="header-btn" id="btn-favorite" title="Favoritar" style="margin-left:4px">⭐</button>
	  </div>
	</div>
	<div class="details-photo" id="sel-photo"><div class="placeholder">📷</div></div>
	<div class="details-route" id="sel-route-box" style="display:none">
	  <span class="airports"><span id="sel-origin">—</span><span class="arrow">→</span><span id="sel-dest">—</span></span>
	</div>
	<div class="details-grid">
	  <div class="details-stat"><div class="details-stat-label">Altitude</div><div class="details-stat-value" id="sel-alt">--</div></div>
	  <div class="details-stat"><div class="details-stat-label">Velocidade</div><div class="details-stat-value" id="sel-speed">--</div></div>
	  <div class="details-stat"><div class="details-stat-label">V/S</div><div class="details-stat-value" id="sel-vrate">--</div></div>
	  <div class="details-stat"><div class="details-stat-label">Heading</div><div class="details-stat-value" id="sel-track">--</div></div>
	  <div class="details-stat"><div class="details-stat-label">Squawk</div><div class="details-stat-value" id="sel-squawk">--</div></div>
	  <div class="details-stat"><div class="details-stat-label">Distância</div><div class="details-stat-value" id="sel-dist">--</div></div>
	</div>
	<div class="altitude-chart">
	  <div class="altitude-chart-label">Altitude</div>
	  <canvas id="alt-chart"></canvas>
	</div>
	<div class="details-actions">
	  <button id="btn-follow">Seguir</button>
	  <button id="btn-center">Centro</button>
	  <button id="btn-share">Share</button>
	  <button id="btn-close">✕</button>
	</div>
	<div class="details-meta">
	  <span id="sel-reg">--</span> | <span id="sel-source">--</span> | <span id="sel-rssi">--</span>
	</div>
  </div>

  <div class="replay-controls" id="replay-controls">
	<button id="replay-back">⏮</button>
	<button id="replay-play">▶</button>
	<button id="replay-forward">⏭</button>
	<input type="range" class="replay-slider" id="replay-slider" min="0" max="100" value="100">
	<span class="replay-time" id="replay-time">Ao Vivo</span>
	<button id="replay-live">LIVE</button>
  </div>

  <div class="geofence-alert" id="geofence-alert">
	<div>⚠️ AERONAVE NO GEOFENCE ⚠️</div>
	<div id="geofence-aircraft">--</div>
  </div>

  <div class="metar-popup" id="metar-popup">
	<h3 id="metar-airport">--</h3>
	<div class="metar-raw" id="metar-raw">--</div>
	<div class="metar-decoded" id="metar-decoded">--</div>
  </div>

  <div class="toast" id="toast">--</div>
  <div class="cache-banner" id="cache-banner">📦 Usando cache</div>

  <div class="modal" id="share-modal">
	<div class="modal-content">
	  <div class="modal-header">
		<h3>Compartilhar</h3>
		<button class="modal-close" id="share-close">✕</button>
	  </div>
	  <input class="modal-input" id="share-url" readonly>
	  <button class="modal-btn" id="share-copy">Copiar Link</button>
	</div>
  </div>

  <script>
"use strict";
var MAPKIT_JWT="__MEULAB_MAPKIT_JWT__",
CACHE_KEY="tar1090_cache",CACHE_MAX_AGE=3e5,MIN_UPDATE_MS=400,MAX_HISTORY=60,PREDICTION_MIN=5,NM2KM=1.852;

var MIL_PFX={FAB:1,BRS:1,FFAB:1,PAT:1,CBJ:1,PBM:1,CPB:1,NAe:1,NAV:1,MAR:1,RCH:1,EVAC:1,REACH:1,CNV:1,DUKE:1,KING:1,JAKE:1,TOPCAT:1,MMF:1,BAF:1,GAF:1,RRR:1,USAF:1,USN:1,USMC:1},
MIL_HEX=[],
EMRG_SQ={7500:1,7600:1,7700:1};

var AIRPORTS=[
  {icao:"SIMK",name:"Franca",lat:-20.5922,lon:-47.3829},
  {icao:"SBSR",name:"São José Rio Preto",lat:-20.8166,lon:-49.4065},
  {icao:"SBBH",name:"Pampulha",lat:-19.8516,lon:-43.9509},
  {icao:"SBSP",name:"Congonhas",lat:-23.6261,lon:-46.6564},
  {icao:"SBGR",name:"Guarulhos",lat:-23.4356,lon:-46.4731},
  {icao:"SBKP",name:"Viracopos",lat:-23.0074,lon:-47.1345},
  {icao:"SBRP",name:"Ribeirão Preto",lat:-21.1364,lon:-47.7767},
  {icao:"SBUL",name:"Uberlândia",lat:-18.8836,lon:-48.2253},
  {icao:"SBCF",name:"Confins",lat:-19.6244,lon:-43.9719},
  {icao:"SBBR",name:"Brasília",lat:-15.8711,lon:-47.9186},
  {icao:"SBGL",name:"Galeão",lat:-22.8090,lon:-43.2506},
  {icao:"SBCT",name:"Curitiba",lat:-25.5285,lon:-49.1758},
  {icao:"SBFL",name:"Florianópolis",lat:-27.6703,lon:-48.5525},
  {icao:"SBPA",name:"Porto Alegre",lat:-29.9944,lon:-51.1714}
];

var $=function(i){return document.getElementById(i)};
var SD=$("status-dot"),SL=$("status-label"),SC=$("status-count"),SV=$("status-visible"),ST=$("status-time"),CB=$("cache-banner"),TOAST=$("toast");
var FT=$("filter-text"),FAL=$("filter-alt-min"),FAH=$("filter-alt-max"),FSL=$("filter-spd-min"),FSH=$("filter-spd-max");
var TT=$("toggle-trails"),TR=$("toggle-rings"),TL=$("toggle-labels"),TM=$("toggle-military"),TA=$("toggle-airports"),TP=$("toggle-prediction"),TTM=$("toggle-terminator");
var TG=$("toggle-geofence"),TMA=$("toggle-mil-alert"),TEA=$("toggle-emerg-alert"),TFA=$("toggle-fav-alert");
var DP=$("details"),XC=$("sel-callsign"),XH=$("sel-hex"),XA=$("sel-alt"),XS=$("sel-speed"),XV=$("sel-vrate"),XT=$("sel-track"),XQ=$("sel-squawk"),XD=$("sel-dist"),XB=$("sel-badge"),XP=$("sel-photo"),XRB=$("sel-route-box"),XO=$("sel-origin"),XDE=$("sel-dest"),XRG=$("sel-reg"),XSR=$("sel-source"),XRS=$("sel-rssi");
var BF=$("btn-follow"),BC=$("btn-center"),BX=$("btn-close"),BS=$("btn-share"),BFV=$("btn-favorite"),BP=$("btn-panel"),BTH=$("btn-theme"),BFS=$("btn-fullscreen"),BSD=$("btn-sound"),BRP=$("btn-replay");
var AG=$("alt-ground"),AL=$("alt-low"),AM=$("alt-medium"),AH=$("alt-high"),AU=$("alt-cruise"),MR=$("msg-rate");
var STT=$("stat-total"),SMA=$("stat-max-alt"),SMS=$("stat-max-speed"),SMI=$("stat-military"),SCL=$("stat-closest"),SFA=$("stat-farthest"),STU=$("stat-update"),SUP=$("stat-uptime");
var RC=$("replay-controls"),RSL=$("replay-slider"),RTM=$("replay-time");
var GA=$("geofence-alert"),GAC=$("geofence-aircraft"),GR=$("geofence-radius");
var MP=$("metar-popup"),MA=$("metar-airport"),MRW=$("metar-raw"),MD=$("metar-decoded");
var SM=$("share-modal"),SU=$("share-url");
var AC_CHART=$("alt-chart");

var MAP=null,RX=null,SEL=null,FOL=false,INF=false,LU=0,FE=0,SOUND_ON=true,DARK_MODE=true,REPLAY_MODE=false,START_TIME=Date.now();
var AC=new Map(),AN=new Map(),HI=new Map(),TL_=new Map(),PL_=new Map(),FAVS=new Set(),ALERTED=new Set(),REPLAY_DATA=[],ALT_HISTORY={};
var AIRPORT_MARKERS=[],RANGE_RINGS=[],TERMINATOR_OVERLAY=null;
var STATS={total_seen:new Set(),max_alt:0,max_speed:0,military_count:0,msg_count:0,last_msg_time:Date.now(),msg_rates:[]};
var PHOTO_CACHE={},PHOTO_ACTIVE_REG=null,PHOTO_LOADING_REG=null;
var AUDIO_CTX=null;

function deg2rad(d){return d*Math.PI/180}
function haversine(a,b,c,d){var R=6371,dL=deg2rad(c-a),dO=deg2rad(d-b),x=Math.sin(dL/2)*Math.sin(dL/2)+Math.cos(deg2rad(a))*Math.cos(deg2rad(c))*Math.sin(dO/2)*Math.sin(dO/2);return R*2*Math.atan2(Math.sqrt(x),Math.sqrt(1-x))}
function fmtDist(k){return k<1?(k*1000|0)+" m":k<100?k.toFixed(1)+" km":(k|0)+" km"}
function fmtDistNm(k){return(k/NM2KM).toFixed(1)+" nm"}
function fmtTime(){var d=new Date();return d.toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit',second:'2-digit'})}
function fmtUptime(ms){var s=Math.floor(ms/1000),m=Math.floor(s/60),h=Math.floor(m/60);return h>0?h+"h "+(m%60)+"m":m>0?m+"m "+(s%60)+"s":s+"s"}
function altColor(a){return a==null||a==="ground"||a<=0?"#6b7785":a<1e4?"#22c55e":a<25e3?"#3b9eff":a<35e3?"#f59e0b":"#ef4444"}
function isMilHex(h){var n=parseInt(h,16);for(var i=0;i<MIL_HEX.length;i++)if(n>=MIL_HEX[i][0]&&n<=MIL_HEX[i][1])return true;return false}
function isMilCs(c){if(!c)return false;for(var i=2;i<=4;i++){var p=c.slice(0,i).toUpperCase();if(MIL_PFX[p])return true}return false}
function isEmrg(s){return EMRG_SQ[s]||false}

function saveCache(d){try{localStorage.setItem(CACHE_KEY,JSON.stringify({t:Date.now(),d:d}))}catch(e){}}
function loadCache(){try{var c=JSON.parse(localStorage.getItem(CACHE_KEY));if(c&&Date.now()-c.t<CACHE_MAX_AGE)return c.d}catch(e){}return null}
function saveFavs(){try{localStorage.setItem("tar1090_favs",JSON.stringify([...FAVS]))}catch(e){}}
function loadFavs(){try{var f=JSON.parse(localStorage.getItem("tar1090_favs"));if(f&&Array.isArray(f))FAVS=new Set(f)}catch(e){}}

function initAudio(){if(!AUDIO_CTX)AUDIO_CTX=new(window.AudioContext||window.webkitAudioContext)()}
function playAlert(type){if(!SOUND_ON)return;initAudio();var o=AUDIO_CTX.createOscillator(),g=AUDIO_CTX.createGain();o.connect(g);g.connect(AUDIO_CTX.destination);
if(type==="emergency"){o.frequency.value=880;g.gain.value=.3;o.start();o.stop(AUDIO_CTX.currentTime+.5)}
else if(type==="military"){o.frequency.value=660;g.gain.value=.2;o.start();o.stop(AUDIO_CTX.currentTime+.3)}
else if(type==="geofence"){o.frequency.value=440;g.gain.value=.25;o.start();o.stop(AUDIO_CTX.currentTime+.4)}
else if(type==="favorite"){o.frequency.value=520;g.gain.value=.15;o.start();o.stop(AUDIO_CTX.currentTime+.2)}
if(navigator.vibrate)navigator.vibrate(type==="emergency"?[200,100,200]:100)}

function showToast(m){TOAST.textContent=m;TOAST.classList.add("visible");setTimeout(function(){TOAST.classList.remove("visible")},3000)}
function setOnline(on,cached){SD.className="status-dot"+(cached?" cached":(on?"":" offline"));SL.textContent=cached?"Cache":(on?"Ao vivo":"Offline");CB.classList.toggle("visible",cached)}

function passFilter(p){var f=FT.value.toUpperCase();if(f){var c=(p.flight||"").toUpperCase(),h=(p.hex||"").toUpperCase(),t=(p.t||p.type||"").toUpperCase();if(c.indexOf(f)<0&&h.indexOf(f)<0&&t.indexOf(f)<0)return false}
var alt=p.alt_baro!==undefined?p.alt_baro:p.alt_geom,spd=p.gs!==undefined?p.gs:p.tas;
if(FAL.value&&alt!==undefined&&alt!=="ground"&&alt<parseInt(FAL.value))return false;
if(FAH.value&&alt!==undefined&&alt!=="ground"&&alt>parseInt(FAH.value))return false;
if(FSL.value&&spd!==undefined&&spd<parseInt(FSL.value))return false;
if(FSH.value&&spd!==undefined&&spd>parseInt(FSH.value))return false;
return true}

function updateHist(h,lat,lon){var hi=HI.get(h);if(!hi){hi=[];HI.set(h,hi)}var l=hi[hi.length-1];if(l&&l.lat===lat&&l.lon===lon)return;hi.push({lat:lat,lon:lon,t:Date.now()});if(hi.length>MAX_HISTORY)hi.shift()}

function updateTrail(h,color){if(!MAP||!mapkit.PolylineOverlay)return;var hi=HI.get(h);if(!hi||hi.length<2)return;var coords=hi.map(function(p){return new mapkit.Coordinate(p.lat,p.lon)});var o=TL_.get(h);if(!o){o=new mapkit.PolylineOverlay(coords,{style:new mapkit.Style({lineWidth:2,strokeColor:color,strokeOpacity:.7})});MAP.addOverlay(o);TL_.set(h,o)}else{o.points=coords;o.style.strokeColor=color}}

function clearTrail(h){var o=TL_.get(h);if(o&&MAP)MAP.removeOverlay(o);TL_.delete(h);HI.delete(h);var p=PL_.get(h);if(p&&MAP)MAP.removeOverlay(p);PL_.delete(h)}
function clearAllTrails(){TL_.forEach(function(o){if(MAP)MAP.removeOverlay(o)});TL_.clear();HI.clear();PL_.forEach(function(o){if(MAP)MAP.removeOverlay(o)});PL_.clear()}

function updatePrediction(h,lat,lon,track,spd){if(!MAP||!TP.checked||!mapkit.PolylineOverlay)return;if(track==null||spd==null||spd<50){var ex=PL_.get(h);if(ex){MAP.removeOverlay(ex);PL_.delete(h)}return}
var distKm=(spd*NM2KM)*(PREDICTION_MIN/60),tr=deg2rad(track),lat2=lat+(distKm/111.32)*Math.cos(tr),lon2=lon+(distKm/(111.32*Math.cos(deg2rad(lat))))*Math.sin(tr);
var coords=[new mapkit.Coordinate(lat,lon),new mapkit.Coordinate(lat2,lon2)];var o=PL_.get(h);if(!o){o=new mapkit.PolylineOverlay(coords,{style:new mapkit.Style({lineWidth:2,strokeColor:"rgba(255,255,255,0.3)",lineDash:[8,4]})});MAP.addOverlay(o);PL_.set(h,o)}else{o.points=coords}}

function updateRings(){if(!MAP||!RX)return;RANGE_RINGS.forEach(function(r){MAP.removeOverlay(r)});RANGE_RINGS=[];if(!TR.checked||!mapkit.CircleOverlay)return;[50,100,150,200].forEach(function(nm){var r=new mapkit.CircleOverlay(new mapkit.Coordinate(RX.lat,RX.lon),nm*1852,{style:new mapkit.Style({lineWidth:1,strokeColor:"rgba(59,158,255,0.4)",fillColor:"transparent"})});MAP.addOverlay(r);RANGE_RINGS.push(r)})}

function updateAirports(){AIRPORT_MARKERS.forEach(function(m){MAP.removeAnnotation(m)});AIRPORT_MARKERS=[];if(!TA.checked)return;AIRPORTS.forEach(function(apt){var el=document.createElement("div");el.className="airport-marker";el.innerHTML='<div class="airport-icon">🛫</div><div class="airport-label">'+apt.icao+'</div>';var m=new mapkit.Annotation(new mapkit.Coordinate(apt.lat,apt.lon),function(){return el},{title:apt.name,anchorOffset:new DOMPoint(0,0),calloutEnabled:false});m.addEventListener("select",function(){fetchMETAR(apt)});MAP.addAnnotation(m);AIRPORT_MARKERS.push(m)})}

function fetchMETAR(apt){var url="https://api.open-meteo.com/v1/forecast?latitude="+apt.lat+"&longitude="+apt.lon+"&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code,cloud_cover,surface_pressure&timezone=America/Sao_Paulo";fetch(url).then(function(r){return r.json()}).then(function(d){if(d&&d.current){var c=d.current,raw=apt.icao+" "+new Date().toISOString().slice(11,16)+"Z "+Math.round(c.wind_direction_10m)+"/"+(c.wind_speed_10m*0.54|0)+"KT "+c.temperature_2m+"C Q"+(c.surface_pressure|0),dec="Temp:"+c.temperature_2m+"°C | Umid:"+c.relative_humidity_2m+"% | Vento:"+Math.round(c.wind_direction_10m)+"°@"+(c.wind_speed_10m*0.54|0)+"kt | Nuvens:"+c.cloud_cover+"%";showMETAR(apt.icao+" - "+apt.name,raw,dec)}}).catch(function(){showMETAR(apt.icao,"Dados indisponíveis","")})}
function showMETAR(icao,raw,dec){MA.textContent=icao;MRW.textContent=raw;MD.textContent=dec;MP.classList.add("visible");MP.style.left="50%";MP.style.top="50%";MP.style.transform="translate(-50%,-50%)";setTimeout(function(){MP.classList.remove("visible")},8000)}

function updateTerminator(){if(!MAP)return;if(TERMINATOR_OVERLAY){MAP.removeOverlay(TERMINATOR_OVERLAY);TERMINATOR_OVERLAY=null}if(!TTM.checked||!mapkit.PolygonOverlay)return;
var now=new Date(),jd=now.getTime()/864e5+2440587.5,n=jd-2451545,L=(280.46+.9856474*n)%360,g=(357.528+.9856003*n)%360,lam=L+1.915*Math.sin(deg2rad(g))+.02*Math.sin(deg2rad(2*g)),eps=23.439-.0000004*n,sunDec=Math.asin(Math.sin(deg2rad(eps))*Math.sin(deg2rad(lam)))*180/Math.PI,eqT=4*(L-.0057183-lam+eps*Math.tan(deg2rad(lam))),sunLon=-15*(now.getUTCHours()+now.getUTCMinutes()/60-12+eqT/60);
var coords=[];for(var lon=-180;lon<=180;lon+=5){var lat=Math.atan(-Math.cos(deg2rad(lon-sunLon))/Math.tan(deg2rad(sunDec)))*180/Math.PI;coords.push(new mapkit.Coordinate(lat,lon))}
if(sunDec>=0){coords.push(new mapkit.Coordinate(-90,180));coords.push(new mapkit.Coordinate(-90,-180))}else{coords.push(new mapkit.Coordinate(90,180));coords.push(new mapkit.Coordinate(90,-180))}
TERMINATOR_OVERLAY=new mapkit.PolygonOverlay([coords],{style:new mapkit.Style({fillColor:"rgba(0,0,30,0.3)",strokeColor:"rgba(255,200,100,0.5)",lineWidth:1})});MAP.addOverlay(TERMINATOR_OVERLAY)}

function checkGeofence(list){if(!TG.checked||!RX)return;var rad=(parseFloat(GR.value)||50)*NM2KM;list.forEach(function(p){if(p.lat==null||p.lon==null)return;var dist=haversine(RX.lat,RX.lon,p.lat,p.lon),h=p.hex||"",cs=(p.flight||"").trim()||h.toUpperCase();
if(dist<=rad&&!ALERTED.has("geo_"+h)){ALERTED.add("geo_"+h);playAlert("geofence");GAC.textContent=cs+" - "+fmtDistNm(dist);GA.classList.add("visible");setTimeout(function(){GA.classList.remove("visible")},5000)}else if(dist>rad*1.1){ALERTED.delete("geo_"+h)}})}

function updateAltBar(list){var g=0,l=0,m=0,h=0,c=0,t=list.length||1;list.forEach(function(p){var a=p.alt_baro!==undefined?p.alt_baro:p.alt_geom;if(a==null||a==="ground"||a<=0)g++;else if(a<1e4)l++;else if(a<25e3)m++;else if(a<35e3)h++;else c++});AG.style.width=(g/t*100)+"%";AL.style.width=(l/t*100)+"%";AM.style.width=(m/t*100)+"%";AH.style.width=(h/t*100)+"%";AU.style.width=(c/t*100)+"%"}

function updateStats(list){var military=0,closest=Infinity,farthest=0;list.forEach(function(p){var h=p.hex||"",cs=(p.flight||"").trim()||h.toUpperCase();STATS.total_seen.add(h);var a=p.alt_baro!==undefined?p.alt_baro:p.alt_geom;if(a!=null&&a!=="ground"&&a>STATS.max_alt)STATS.max_alt=a;var s=p.gs!==undefined?p.gs:p.tas;if(s!=null&&s>STATS.max_speed)STATS.max_speed=Math.round(s);if(isMilHex(h)||isMilCs(p.flight))military++;if(RX&&p.lat!=null&&p.lon!=null){var d=haversine(RX.lat,RX.lon,p.lat,p.lon);if(d<closest)closest=d;if(d>farthest)farthest=d}});STATS.military_count=military;STT.textContent=STATS.total_seen.size;SMA.textContent=STATS.max_alt.toLocaleString();SMS.textContent=STATS.max_speed;SMI.textContent=military;SCL.textContent=closest<Infinity?fmtDistNm(closest):"--";SFA.textContent=farthest>0?fmtDistNm(farthest):"--";STU.textContent=fmtTime();SUP.textContent=fmtUptime(Date.now()-START_TIME)}

function fetchPhoto(h,reg){
if(!reg){XP.innerHTML='<div class="placeholder">📷</div>';return}
if(PHOTO_ACTIVE_REG===reg&&XP.querySelector("img"))return;
if(PHOTO_CACHE[reg]){
XP.innerHTML="";
XP.appendChild(PHOTO_CACHE[reg].cloneNode(true));
PHOTO_ACTIVE_REG=reg;
return;
}
if(PHOTO_LOADING_REG===reg)return;
PHOTO_LOADING_REG=reg;
XP.innerHTML='<div class="placeholder">📷</div>';
var url="https://api.planespotters.net/pub/photos/reg/"+encodeURIComponent(reg);
fetch(url).then(function(r){return r.json()}).then(function(d){
if(!d||!d.photos||!d.photos.length){PHOTO_LOADING_REG=null;return}
var photo=d.photos[0];
var src=(photo.thumbnail_large&&photo.thumbnail_large.src)||(photo.thumbnail&&photo.thumbnail.src);
if(!src){PHOTO_LOADING_REG=null;return}
var img=new Image();
img.onload=function(){
PHOTO_CACHE[reg]=img;
if(PHOTO_LOADING_REG===reg){
XP.innerHTML="";
XP.appendChild(img.cloneNode(true));
PHOTO_ACTIVE_REG=reg;
}
PHOTO_LOADING_REG=null;
};
img.onerror=function(){PHOTO_LOADING_REG=null};
img.src=src;
}).catch(function(){PHOTO_LOADING_REG=null});
}

function updateAltChart(h){if(!AC_CHART)return;var ctx=AC_CHART.getContext("2d"),w=AC_CHART.width=AC_CHART.offsetWidth*2,ht=AC_CHART.height=AC_CHART.offsetHeight*2;ctx.clearRect(0,0,w,ht);var hi=ALT_HISTORY[h]||[];if(hi.length<2)return;var mx=Math.max(...hi.map(function(p){return p.alt||0}),1000);ctx.strokeStyle="#3b9eff";ctx.lineWidth=2;ctx.beginPath();hi.forEach(function(p,i){var x=(i/(hi.length-1))*w,y=ht-((p.alt||0)/mx)*(ht-10);i===0?ctx.moveTo(x,y):ctx.lineTo(x,y)});ctx.stroke();ctx.lineTo(w,ht);ctx.lineTo(0,ht);ctx.closePath();var gr=ctx.createLinearGradient(0,0,0,ht);gr.addColorStop(0,"rgba(59,158,255,0.3)");gr.addColorStop(1,"rgba(59,158,255,0)");ctx.fillStyle=gr;ctx.fill()}

function recordAlt(h,a){if(!ALT_HISTORY[h])ALT_HISTORY[h]=[];ALT_HISTORY[h].push({alt:a||0,t:Date.now()});if(ALT_HISTORY[h].length>60)ALT_HISTORY[h].shift()}

function selectAC(h){SEL=h;var p=AC.get(h);if(!p){DP.classList.add("hidden");return}DP.classList.remove("hidden");var cs=(p.flight||"").trim()||h.toUpperCase(),a=p.alt_baro!==undefined?p.alt_baro:p.alt_geom,s=p.gs!==undefined?Math.round(p.gs):null,v=p.baro_rate||p.geom_rate,t=p.track||p.true_heading,q=p.squawk,iM=isMilHex(h)||isMilCs(p.flight),iE=isEmrg(q),iF=FAVS.has(h)||FAVS.has(cs);
XC.textContent=cs;XH.textContent=h.toUpperCase();XA.textContent=(a!=null&&a!=="ground")?a.toLocaleString()+" ft":"Solo";XS.textContent=s!=null?s+" kt":"--";
if(v!=null&&v!==0){XV.textContent=(v>0?"+":"")+v+" fpm";XV.className="details-stat-value"+(v>100?" climbing":(v<-100?" descending":""))}else{XV.textContent="0 fpm";XV.className="details-stat-value"}
XT.textContent=t!=null?Math.round(t)+"°":"--";XQ.textContent=q||"--";XQ.style.color=iE?"var(--bad)":"";
XD.textContent=(RX&&p.lat!=null&&p.lon!=null)?fmtDistNm(haversine(RX.lat,RX.lon,p.lat,p.lon)):"--";
XB.textContent=p.t||p.type||"?";XB.className="details-badge"+(iE?" emergency":(iM?" military":""));
if(p.route&&p.route.length>=2){XO.textContent=p.route[0];XDE.textContent=p.route[p.route.length-1];XRB.style.display="block"}else{XRB.style.display="none"}
var srcLabel=p.src==="opensky"?"Global (OpenSky)":"Local (SDR)";
XRG.textContent="Reg:"+(p.r||"--");XSR.textContent=srcLabel;XRS.textContent=p.rssi?"RSSI:"+p.rssi+"dB":"";
BFV.textContent=iF?"★":"☆";BFV.classList.toggle("active",iF);fetchPhoto(h,p.r);updateAltChart(h)}

function createAC(h,cs,a,t,iM,iE,sL,iF,src){var col=altColor(a),cls="aircraft-container";if(SEL===h)cls+=" selected";if(iE)cls+=" emergency";else if(iM)cls+=" military";if(iF)cls+=" favorite";if(src==="opensky")cls+=" opensky";var el=document.createElement("div");
el.className=cls;var ic=document.createElement("div");ic.className="aircraft-icon";ic.innerHTML="✈";ic.style.cssText="transform:rotate("+((t||0)-90)+"deg);color:"+(iE?"var(--bad)":(iM?"var(--military)":(src==="opensky"?"var(--warn)":col)));el.appendChild(ic);if(sL){var lb=document.createElement("div");lb.className="aircraft-label";lb.textContent=(cs||h.toUpperCase()).slice(0,8);el.appendChild(lb)}return el}

function processData(data){var list=data.aircraft||[],seen=new Set(),filtered=[],sL=TL.checked,sT=TT.checked,hM=TM.checked;if(!sT)clearAllTrails();
var now=Date.now();if(data.messages&&STATS.msg_count>0){var el=(now-STATS.last_msg_time)/1000;if(el>=0.3){var rate=(data.messages-STATS.msg_count)/el;STATS.msg_rates.push(rate);if(STATS.msg_rates.length>5)STATS.msg_rates.shift();var avg=Math.round(STATS.msg_rates.reduce(function(a,b){return a+b},0)/STATS.msg_rates.length);MR.textContent=avg>0?avg:0;STATS.msg_count=data.messages;STATS.last_msg_time=now}}else if(data.messages){STATS.msg_count=data.messages;STATS.last_msg_time=now}

for(var i=0;i<list.length;i++){var p=list[i];if(!p||p.lat==null||p.lon==null)continue;if(p.seen!=null&&p.seen>30)continue;var h=p.hex||p.icao||"";if(!h||!passFilter(p))continue;seen.add(h);AC.set(h,p);filtered.push(p)}
SC.textContent=list.length;SV.textContent=filtered.length;

for(var j=0;j<filtered.length;j++){var q=filtered[j],hx=q.hex||q.icao||"",al=q.alt_baro!==undefined?q.alt_baro:q.alt_geom,tr=q.track||q.true_heading||0,sp=q.gs||q.tas,col=altColor(al),cs=(q.flight||"").trim(),iM=hM&&(isMilHex(hx)||isMilCs(cs)),iE=isEmrg(q.squawk),iF=FAVS.has(hx)||FAVS.has(cs);
recordAlt(hx,al);
if(iE&&TEA.checked&&!ALERTED.has("emrg_"+hx)){ALERTED.add("emrg_"+hx);playAlert("emergency");showToast("🚨 EMERGÊNCIA: "+(cs||hx))}
if(iM&&TMA.checked&&!ALERTED.has("mil_"+hx)){ALERTED.add("mil_"+hx);playAlert("military");showToast("🎖️ MILITAR: "+(cs||hx))}
if(iF&&TFA.checked&&!ALERTED.has("fav_"+hx)){ALERTED.add("fav_"+hx);playAlert("favorite");showToast("⭐ FAVORITO: "+(cs||hx))}

var an=AN.get(hx);if(!an){an=new mapkit.Annotation(new mapkit.Coordinate(q.lat,q.lon),(function(H,C,A,T,M,E,F,S){return function(){return createAC(H,C,A,T,M,E,sL,F,S)}})(hx,cs,al,tr,iM,iE,iF,q.src),{anchorOffset:new DOMPoint(0,0),calloutEnabled:false});an.data={h:hx};MAP.addAnnotation(an);AN.set(hx,an);(function(H){an.addEventListener("select",function(){selectAC(H)})})(hx)}else{an.coordinate=new mapkit.Coordinate(q.lat,q.lon)}

var el=an.element;if(el){var cls="aircraft-container";if(SEL===hx)cls+=" selected";if(iE)cls+=" emergency";else if(iM)cls+=" military";if(iF)cls+=" favorite";if(q.src==="opensky")cls+=" opensky";el.className=cls;var ic=el.firstChild;if(ic)ic.style.cssText="transform:rotate("+(tr-90)+"deg);color:"+(iE?"var(--bad)":(iM?"var(--military)":(q.src==="opensky"?"var(--warn)":col)));var lb=el.children[1];
if(sL){if(!lb){lb=document.createElement("div");lb.className="aircraft-label";el.appendChild(lb)}lb.textContent=(cs||hx.toUpperCase()).slice(0,8);lb.style.display=""}else if(lb)lb.style.display="none"}
if(sT){updateHist(hx,q.lat,q.lon);updateTrail(hx,col)}
updatePrediction(hx,q.lat,q.lon,tr,sp)}

AN.forEach(function(a,h){if(!seen.has(h)){MAP.removeAnnotation(a);AN.delete(h);clearTrail(h);AC.delete(h);ALT_HISTORY[h]=null;ALERTED.delete("emrg_"+h);ALERTED.delete("mil_"+h);ALERTED.delete("fav_"+h);ALERTED.delete("geo_"+h)}}); 

if(SEL){if(AC.has(SEL)){selectAC(SEL);if(FOL){var fp=AC.get(SEL);MAP.center=new mapkit.Coordinate(fp.lat,fp.lon)}}else{DP.classList.add("hidden");SEL=null}}
checkGeofence(filtered);updateAltBar(filtered);updateStats(filtered);ST.textContent=fmtTime();
if(!REPLAY_MODE){REPLAY_DATA.push({t:Date.now(),d:data});if(REPLAY_DATA.length>300)REPLAY_DATA.shift()}}

function fetchData(){if(INF||REPLAY_MODE||document.hidden)return;var now=Date.now();if(now-LU<MIN_UPDATE_MS)return;LU=now;INF=true;
fetch("/data/aircraft.json",{cache:"no-store"}).then(function(r){if(!r.ok)throw new Error(r.status);return r.json()}).then(function(d){FE=0;setOnline(true,false);saveCache(d);requestAnimationFrame(function(){processData(d)})}).catch(function(){FE++;if(FE>=3){var c=loadCache();if(c){setOnline(false,true);processData(c)}else setOnline(false,false)}}).finally(function(){INF=false})}

function fetchRX(){fetch("/data/receiver.json",{cache:"no-store"}).then(function(r){return r.json()}).then(function(d){if(!d||!d.lat||!d.lon)return;RX=d;$("receiver-info").textContent=d.lat.toFixed(4)+", "+d.lon.toFixed(4);if(!MAP._centered){MAP.region=new mapkit.CoordinateRegion(new mapkit.Coordinate(d.lat,d.lon),new mapkit.CoordinateSpan(3,3));MAP._centered=true}updateRings();updateAirports();updateTerminator();if(!MAP._rm){var el=document.createElement("div");el.className="receiver-marker";var m=new mapkit.Annotation(new mapkit.Coordinate(d.lat,d.lon),function(){return el},{title:"Receptor",anchorOffset:new DOMPoint(0,0)});MAP.addAnnotation(m);MAP._rm=m}}).catch(function(){$("receiver-info").textContent="--"})}

function renderFavs(){var list=$("fav-list");list.innerHTML="";FAVS.forEach(function(f){var item=document.createElement("div");item.className="fav-item";var online=false;AC.forEach(function(p,h){if(h===f||(p.flight&&p.flight.trim().toUpperCase()===f.toUpperCase()))online=true});item.innerHTML='<div><span class="callsign">'+f.toUpperCase()+'</span><br><span class="fav-status">'+(online?"🟢 Online":"⚫ Offline")+'</span></div><button class="fav-remove" data-fav="'+f+'">✕</button>';item.addEventListener("click",function(e){if(e.target.classList.contains("fav-remove")){var fv=e.target.dataset.fav;FAVS.delete(fv);saveFavs();renderFavs()}else{AC.forEach(function(p,h){if(h===f||(p.flight&&p.flight.trim().toUpperCase()===f.toUpperCase())){selectAC(h);var an=AN.get(h);if(an)MAP.center=an.coordinate}})}});list.appendChild(item)})}

function setMapType(t){if(!MAP)return;document.querySelectorAll(".map-type-toggle button").forEach(function(b){b.classList.remove("active")});$("map-"+t).classList.add("active");MAP.mapType=t==="satellite"?mapkit.Map.MapTypes.Satellite:t==="hybrid"?mapkit.Map.MapTypes.Hybrid:mapkit.Map.MapTypes.Standard}
function toggleTheme(){DARK_MODE=!DARK_MODE;document.documentElement.setAttribute("data-theme",DARK_MODE?"dark":"light");if(MAP)MAP.colorScheme=DARK_MODE?mapkit.Map.ColorSchemes.Dark:mapkit.Map.ColorSchemes.Light}
function toggleFS(){var m=$("map");if(!document.fullscreenElement&&!document.webkitFullscreenElement){if(m.requestFullscreen)m.requestFullscreen();else if(m.webkitRequestFullscreen)m.webkitRequestFullscreen()}else{if(document.exitFullscreen)document.exitFullscreen();else if(document.webkitExitFullscreen)document.webkitExitFullscreen()}}
function toggleReplay(){REPLAY_MODE=!REPLAY_MODE;RC.classList.toggle("visible",REPLAY_MODE);BRP.classList.toggle("active",REPLAY_MODE);if(!REPLAY_MODE){RTM.textContent="Ao Vivo";RSL.value=100}}
function replayAt(pct){if(!REPLAY_MODE||REPLAY_DATA.length===0)return;var idx=Math.floor((pct/100)*(REPLAY_DATA.length-1));var d=REPLAY_DATA[idx];if(d){var dt=new Date(d.t);RTM.textContent=dt.toLocaleTimeString('pt-BR',{hour:'2-digit',minute:'2-digit',second:'2-digit'});processData(d.d)}}
function shareAC(){if(!SEL)return;var p=AC.get(SEL);if(!p)return;var url=window.location.origin+window.location.pathname+"?track="+SEL;if(p.lat&&p.lon)url+="&lat="+p.lat.toFixed(4)+"&lon="+p.lon.toFixed(4);SU.value=url;SM.classList.add("visible")}

function setupTabs(){document.querySelectorAll(".panel-tab").forEach(function(tab){tab.addEventListener("click",function(){document.querySelectorAll(".panel-tab").forEach(function(t){t.classList.remove("active")});document.querySelectorAll(".panel-section").forEach(function(s){s.classList.remove("active")});tab.classList.add("active");$("tab-"+tab.dataset.tab).classList.add("active");if(tab.dataset.tab==="favorites")renderFavs()})})}

function init(){if(!MAPKIT_JWT){$("receiver-info").textContent="Token inválido";return}loadFavs();
mapkit.init({authorizationCallback:function(d){d(MAPKIT_JWT)}});
MAP=new mapkit.Map("map",{showsCompass:mapkit.FeatureVisibility.Visible,showsScale:mapkit.FeatureVisibility.Visible,showsZoomControl:true,mapType:mapkit.Map.MapTypes.Standard,colorScheme:mapkit.Map.ColorSchemes.Dark});
MAP.addEventListener("region-change-end",function(){
    var r=MAP.region,c=r.center,s=r.span;
    var minLa=c.latitude-s.latitudeDelta/2,maxLa=c.latitude+s.latitudeDelta/2;
    var minLo=c.longitude-s.longitudeDelta/2,maxLo=c.longitude+s.longitudeDelta/2;
    if(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.onMapChange){
        window.webkit.messageHandlers.onMapChange.postMessage([minLa,maxLa,minLo,maxLo]);
    }
});

$("map-standard").onclick=function(){setMapType("standard")};$("map-satellite").onclick=function(){setMapType("satellite")};$("map-hybrid").onclick=function(){setMapType("hybrid")};
BP.onclick=function(){$("panel").classList.toggle("hidden");BP.classList.toggle("active")};
BP.classList.remove("active");$("panel").classList.add("hidden");
BTH.onclick=toggleTheme;BFS.onclick=toggleFS;
BSD.onclick=function(){SOUND_ON=!SOUND_ON;BSD.classList.toggle("active",SOUND_ON);BSD.textContent=SOUND_ON?"🔔":"🔕";if(SOUND_ON)initAudio()};
BRP.onclick=toggleReplay;

BF.onclick=function(){FOL=!FOL;BF.textContent=FOL?"Seguindo":"Seguir";BF.classList.toggle("active",FOL)};
BC.onclick=function(){if(RX)MAP.center=new mapkit.Coordinate(RX.lat,RX.lon)};
BX.onclick=function(){DP.classList.add("hidden");SEL=null;FOL=false;BF.textContent="Seguir";BF.classList.remove("active")};
BS.onclick=shareAC;
BFV.onclick=function(){if(!SEL)return;var p=AC.get(SEL),cs=p&&p.flight?p.flight.trim().toUpperCase():null;if(FAVS.has(SEL)){FAVS.delete(SEL);if(cs)FAVS.delete(cs)}else FAVS.add(SEL);saveFavs();selectAC(SEL);renderFavs()};

$("fav-add").onclick=function(){var v=$("fav-input").value.trim().toUpperCase();if(v){FAVS.add(v);saveFavs();renderFavs();$("fav-input").value="";showToast("⭐ Favorito: "+v)}};

TR.onchange=updateRings;TT.onchange=function(){if(!this.checked)clearAllTrails()};TA.onchange=updateAirports;TTM.onchange=updateTerminator;

var ft;function deb(){clearTimeout(ft);ft=setTimeout(function(){LU=0},150)}
FT.oninput=FAL.oninput=FAH.oninput=FSL.oninput=FSH.oninput=deb;

RSL.oninput=function(){replayAt(parseInt(this.value))};
$("replay-live").onclick=function(){REPLAY_MODE=false;RC.classList.remove("visible");BRP.classList.remove("active");RTM.textContent="Ao Vivo";RSL.value=100};
$("replay-back").onclick=function(){RSL.value=Math.max(0,parseInt(RSL.value)-5);replayAt(parseInt(RSL.value))};
$("replay-forward").onclick=function(){RSL.value=Math.min(100,parseInt(RSL.value)+5);replayAt(parseInt(RSL.value))};

$("share-close").onclick=function(){SM.classList.remove("visible")};
$("share-copy").onclick=function(){SU.select();document.execCommand("copy");showToast("Link copiado!");SM.classList.remove("visible")};

document.addEventListener("click",function(e){if(!MP.contains(e.target))MP.classList.remove("visible")});
setupTabs();

var params=new URLSearchParams(window.location.search);if(params.get("track"))setTimeout(function(){selectAC(params.get("track"))},2000);

fetchRX();fetchData();setInterval(fetchData,MIN_UPDATE_MS);setInterval(fetchRX,15000);setInterval(updateTerminator,60000);
$("title").onclick=function(){if(RX)MAP.center=new mapkit.Coordinate(RX.lat,RX.lon)}}
init();
  </script>
</body>
</html>
"""#
}
