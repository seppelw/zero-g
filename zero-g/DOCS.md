# Home Assistant Add-on: Zero-G (Antigravity Assistant)

Das **Zero-G** Add-on bringt das autonome Google Antigravity KI-Entwicklungssystem direkt in dein Home Assistant. Mit nativer Ingress-Einbindung steht dir das vollständige Webinterface ohne Portweiterleitungen direkt in der Home Assistant Seitenleiste zur Verfügung.

---

## 🚀 Schnellstart & Onboarding

### 1. Installation
1. Klicke im Add-on Store auf **Installieren**.
2. Aktiviere nach der Installation den Schalter **In der Seitenleiste anzeigen**.
3. Klicke auf **Starten**.

### 2. Erstmalige Authentifizierung
Antigravity benötigt eine einmalige Autorisierung mit deinem Google-Konto:

- **Weg A (Über das Log - Empfohlen)**:
  1. Öffne den Reiter **Protokoll** (Log) des Add-ons.
  2. Kopiere den dort angezeigten Anmelde-Link und öffne ihn in deinem Browser.
  3. Bestätige die Autorisierung. Nach wenigen Augenblicken schaltet Zero-G automatisch in den aktiven Betriebsmodus.
- **Weg B (Direktes Token)**:
  Falls du bereits ein OAuth-Token besitzt, kannst du es in den Add-on Einstellungen im Feld `auth_token` hinterlegen.

### 3. Webinterface öffnen
Klicke in der linken Seitenleiste von Home Assistant auf **Zero-G**. Du bist sofort startklar!

---

## 🔌 Home Assistant MCP Server (Model Context Protocol)

Zero-G unterstützt und verbindet automatisch beide Home Assistant MCP-Varianten:

1. **Nativer Core MCP Server (`mcp_server`, `/api/mcp`)**:
   - Die offizielle Home Assistant Core-Integration zur Sprach- und Assist-Steuerung.
   - Ermöglicht das Schalten von Entitäten (Lichter, Schalter, Thermostate, Szenen, Skripte) und den Abruf von Live-Kontext.
   - [🔗 Jetzt mit My Home Assistant einrichten](https://my.home-assistant.io/redirect/config_flow_start/?domain=mcp_server)

2. **Community MCP Server (`czechbol/hass-mcp`, `/api/hass_mcp`)**:
   - Die erweiterte Entwickler-Integration (über HACS) für vollständige Administration.
   - Ermöglicht das Bearbeiten von YAML-Dateien unter `/config`, Lovelace-Dashboards, HACS-Paketen und Backups.
   - [📦 In HACS öffnen](https://my.home-assistant.io/redirect/hacs_repository/?owner=czechbol&repository=hass-mcp&category=integration) | [🔗 Integration hinzufügen](https://my.home-assistant.io/redirect/config_flow_start/?domain=hass_mcp)

- **Automatischer Modus (`ha_mcp_mode: auto`)**:
  Das Add-on nutzt das interne Supervisor-Netzwerk (`http://supervisor/core/api/mcp` und `http://supervisor/core/api/hass_mcp`) und den automatisch bereitgestellten Supervisor-Token. Sobald eine Integration in Home Assistant aktiv ist, wird sie automatisch erkannt und eingebunden.
- **Manueller Modus (`ha_mcp_mode: manual`)**:
  Falls du einen externen Host oder Long-Lived Access Token verwenden möchtest, kannst du deine URL und den Token in der Konfiguration eintragen.

---

## ⚙️ Konfigurationsoptionen

| Option | Typ | Standard | Beschreibung |
|---|---|---|---|
| `auto_update` | boolean | `true` | Prüft bei jedem Start nach der neuesten Antigravity CLI Version und lädt Updates automatisch herunter. |
| `remote_control_name` | string | `"homeassistant-zero-g"` | Anzeigename der Remote-Control-Instanz. |
| `ha_mcp_enabled` | boolean | `true` | Aktiviert die automatische Einbindung des Home Assistant MCP Servers. |
| `ha_mcp_mode` | string | `"auto"` | `auto` (nutzt Supervisor-Token) oder `manual` (nutzt benutzerdefinierten Token). |
| `ha_mcp_url` | string | `""` | Optionaler benutzerdefinierter MCP-Endpunkt (bei leer: `http://supervisor/core/api/mcp`). |
| `ha_mcp_token` | password | `""` | Optionaler Long-Lived Access Token für den manuellen Modus. |
| `ha_mcp_history_enabled` | boolean | `false` | Bindet optional den Home Assistant History MCP Server ein. |
| `ha_mcp_history_url` | string | `""` | Optionaler History MCP Endpunkt (bei leer: `http://supervisor/core/api/hass_mcp`). |
| `auth_token` | password | `""` | Optionales OAuth-Token zur direkten Übergabe. |
| `log_level` | string | `"info"` | Protokollierungsstufe (`trace`, `debug`, `info`, `warning`, `error`). |

---

## 💾 Persistenz & Dateizugriff

Alle Daten werden im persistenten Home Assistant Volume `/data` gespeichert und bleiben über Updates und Reboots hinweg erhalten:
- `/data/.gemini`: OAuth-Tokens, MCP-Server-Konfiguration (`mcp_config.json`), Einstellungen.
- `/data/.antigravity`: Logs, interne Sitzungsdaten.
- `/data/workspace`: Standard-Arbeitsverzeichnis für Projekte und Code.
- `/config`: Direkter Zugriff auf deine Home Assistant Konfigurationsdateien.
- `/share`: Zugriff auf das gemeinsame Home Assistant Share-Verzeichnis.
- `/addons`: Zugriff auf lokale Add-ons.
