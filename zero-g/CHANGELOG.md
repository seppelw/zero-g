# Changelog

## 1.0.1

- 🐛 **Fix**: Dockerfile Build-Konflikt behoben (redundante Bashio-Installation entfernt).

## 1.0.0 (Initial Release: Zero-G)

- 🛸 **Zero-G Launch**: Schwerelose KI-Entwicklung und Smart-Home-Orchestrierung für Home Assistant powered by Google Antigravity.
- ✨ **Automatischer Download & Updates**: Lädt automatisch die neueste offizielle Antigravity Version von Google herunter (Multi-Arch: `amd64` und `aarch64`).
- 🌐 **Home Assistant Ingress**: Nahtlose Einbettung des vollständigen Webinterfaces in die Home Assistant Seitenleiste über integrierten Nginx Reverse Proxy.
- 🔌 **Home Assistant MCP Server Integration**:
  - Automatische 1-Klick-Konfiguration über Home Assistant Supervisor (`http://supervisor/core/api/mcp`).
  - Unterstützung für manuelle URLs und Long-Lived Access Tokens.
  - Optionale Unterstützung für den Home Assistant History MCP Server (`hass_mcp`).
- 🚀 **Geführtes Onboarding**:
  - Responsive Status- und Onboarding-Weboberfläche für Ersteinrichtung mit automatischem Health-Check.
  - Ausgabe der Sign-In URL im Add-on Log.
- 🔒 **Persistente Datenspeicherung**: Sichere Speicherung aller Tokens, Einstellungen und Sitzungen im `/data`-Volume.
- 📂 **Voller Zugriff auf `/config`**: Zero-G kann Home Assistant Automationen, Scripts und Konfigurationen direkt einsehen und bearbeiten.
