# Home Assistant Add-on: Antigravity Assistant & Web UI

Das **Antigravity** Add-on bringt das autonome Google Antigravity KI-Entwicklungssystem direkt in dein Home Assistant. Mit nativer Ingress-Einbindung steht dir das vollständige Antigravity Webinterface ohne zusätzliche Portweiterleitungen direkt in der Home Assistant Seitenleiste zur Verfügung.

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
  3. Bestätige die Autorisierung. Nach wenigen Augenblicken schaltet Antigravity automatisch in den aktiven Betriebsmodus.
- **Weg B (Direktes Token)**:
  Falls du bereits ein OAuth-Token besitzt, kannst du es in den Add-on Einstellungen im Feld `auth_token` hinterlegen.

### 3. Webinterface öffnen
Klicke in der linken Seitenleiste von Home Assistant auf **Antigravity**. Du bist sofort startklar!

---

## 🔌 Home Assistant MCP Server (Model Context Protocol)

Das Add-on konfiguriert den **Home Assistant MCP Server** automatisch vor:

- **Automatischer Modus (`ha_mcp_mode: auto`)**:
  Das Add-on nutzt das interne Supervisor-Netzwerk (`http://supervisor/core/api/mcp`) und den automatisch bereitgestellten Supervisor-Token. Du musst **keine** Token manuell erstellen oder kopieren!
- **Manueller Modus (`ha_mcp_mode: manual`)**:
  Falls du einen Long-Lived Access Token (Langlebigen Zugangs-Token) verwenden möchtest, kannst du deine Home Assistant URL und den Token in der Konfiguration eintragen.
- **MCP Historien-Server (`ha_mcp_history_enabled`)**:
  Aktiviert optional den Endpunkt für Verlaufsdaten und Statistiken (`/api/hass_mcp`).

### Was kann der Agent mit dem MCP-Server tun?
- **Entitäten steuern**: Lichter schalten, Szenen aktivieren, Thermostate einstellen, Staubsauger starten.
- **Zustände abfragen**: Live-Zustände aller Sensoren und Geräte im Smart Home auslesen.
- **Konfigurationen bearbeiten**: Direkter Zugriff auf `/config` (Automatisierungen, Scripts, `configuration.yaml`, Dashboards).

---

## ⚙️ Konfigurationsoptionen

| Option | Typ | Standard | Beschreibung |
|---|---|---|---|
| `auto_update` | boolean | `true` | Prüft bei jedem Start nach der neuesten Antigravity CLI Version und lädt Updates automatisch herunter. |
| `remote_control_name` | string | `"homeassistant-antigravity"` | Anzeigename der Remote-Control-Instanz. |
| `ha_mcp_enabled` | boolean | `true` | Aktiviert die automatische Einbindung des Home Assistant MCP Servers. |
| `ha_mcp_mode` | string | `"auto"` | `auto` (nutzt Supervisor-Token) oder `manual` (nutzt benutzerdefinierten Token). |
| `ha_mcp_url` | string | `"auto"` | MCP-Endpunkt (bei `auto`: `http://supervisor/core/api/mcp`). |
| `ha_mcp_token` | password | `""` | Optionaler Long-Lived Access Token für den manuellen Modus. |
| `ha_mcp_history_enabled` | boolean | `false` | Bindet optional den Home Assistant History MCP Server ein. |
| `ha_mcp_history_url` | string | `"auto"` | History MCP Endpunkt (bei `auto`: `http://supervisor/core/api/hass_mcp`). |
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
