# Home Assistant Add-on: Zero-G (Antigravity Assistant)

[🇬🇧 English Documentation](#english) | [🇩🇪 Deutsche Dokumentation](#deutsch)

<a name="english"></a>
## 🇬🇧 English Documentation

The **Zero-G** add-on integrates the autonomous Google Antigravity AI coding agent and orchestration environment directly into Home Assistant. Featuring native Home Assistant Ingress integration, you can access the full web interface without port forwarding directly from your Home Assistant sidebar.

---

### 🚀 Quick Start & Onboarding

#### 1. Installation
1. In the Home Assistant Add-on Store, search for **Zero-G** and click **Install**.
2. Enable **Show in sidebar** in the add-on settings.
3. Click **Start**.

#### 2. One-Time Google Authentication
Zero-G needs a one-time authorization with your Google account:
- **Method A (Ingress Onboarding Dashboard - Recommended)**:
  1. Open **Zero-G** from your sidebar.
  2. Click **🔗 Sign in with Google now**.
  3. Authorize with your Google account, copy the code (`4/...`), click **⚙️ Go to Add-on Configuration**, paste the code in `auth_token`, and click **Save & Restart**.
- **Method B (Add-on Log)**:
  1. Open the **Log** tab of the add-on.
  2. Copy the authorization URL and open it in your browser.
  3. Confirm the login to authenticate.
- **Method C (Direct Token)**:
  If you already have a valid OAuth token, paste it directly into `auth_token` in the configuration tab.

#### 3. Accessing the Development Environment
Open **Zero-G** from the sidebar or navigate to [antigravity.google](https://antigravity.google/) and connect via **Remote Control** to `homeassistant-zero-g`.

---

### 🔌 Home Assistant MCP Servers (Model Context Protocol)

Zero-G automatically discovers and orchestrates both Home Assistant MCP servers:

1. **Official Core MCP Server (`mcp_server`, `/api/mcp`)**:
   - Built-in Home Assistant Core integration for direct entity control & Assist voice intents (lights, climate, covers, switches, scripts).
   - [🔗 Set up with My Home Assistant](https://my.home-assistant.io/redirect/config_flow_start/?domain=mcp_server)

2. **Community MCP Server (`czechbol/hass-mcp`, `/api/hass_mcp`)**:
   - Advanced developer integration (via HACS) for full administrative power.
   - Edit YAML files in `/config`, modify Lovelace dashboards, manage HACS packages, and trigger backups.
   - [📦 Open in HACS](https://my.home-assistant.io/redirect/hacs_repository/?owner=czechbol&repository=hass-mcp&category=integration) | [🔗 Add Integration](https://my.home-assistant.io/redirect/config_flow_start/?domain=hass_mcp)

- **Auto Mode (`ha_mcp_mode: auto`)**:
  Uses the internal Supervisor network (`http://supervisor/core/api/mcp` and `http://supervisor/core/api/hass_mcp`) and auto-injected Supervisor token. No configuration needed!
- **Manual Mode (`ha_mcp_mode: manual`)**:
  Allows custom endpoints and Long-Lived Access Tokens if running across networks.

---

### ⚙️ Configuration Options

| Option | Type | Default | Description |
|---|---|---|---|
| `auto_update` | boolean | `true` | Checks for latest Antigravity CLI release on startup and auto-updates. |
| `remote_control_name` | string | `"homeassistant-zero-g"` | Instance name displayed on antigravity.google. |
| `ha_mcp_enabled` | boolean | `true` | Enables automatic Home Assistant MCP server integration. |
| `ha_mcp_mode` | string | `"auto"` | `auto` (Supervisor token) or `manual` (custom token). |
| `ha_mcp_url` | string | `""` | Custom Core MCP endpoint (default: `http://supervisor/core/api/mcp`). |
| `ha_mcp_token` | password | `""` | Optional Long-Lived Access Token for manual mode. |
| `ha_mcp_history_enabled` | boolean | `false` | Enables Community MCP / History server integration. |
| `ha_mcp_history_url` | string | `""` | Custom Community MCP endpoint (default: `http://supervisor/core/api/hass_mcp`). |
| `auth_token` | password | `""` | Google OAuth authorization code or token. |
| `log_level` | string | `"info"` | Log level (`trace`, `debug`, `info`, `warning`, `error`). |

---

<a name="deutsch"></a>
## 🇩🇪 Deutsche Dokumentation

Das **Zero-G** Add-on bringt das autonome Google Antigravity KI-Entwicklungssystem direkt in dein Home Assistant. Mit nativer Ingress-Einbindung steht dir das vollständige Webinterface ohne Portweiterleitungen direkt in der Home Assistant Seitenleiste zur Verfügung.

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
