# Changelog

## 1.0.0 (Initial Release)

- ✨ **Automatischer Download**: Lädt automatisch die neueste offizielle Antigravity Version von Google herunter (Multi-Arch: `amd64` und `aarch64`).
- 🌐 **Home Assistant Ingress**: Nahtlose Einbettung des vollständigen Antigravity Webinterfaces in die Home Assistant Seitenleiste über integrierten Nginx Reverse Proxy.
- 🔌 **Home Assistant MCP Server Integration**:
  - Automatische 1-Klick-Konfiguration über Home Assistant Supervisor (`http://supervisor/core/api/mcp`).
  - Unterstützung für manuelle URLs und Long-Lived Access Tokens.
  - Optionale Unterstützung für den Home Assistant History MCP Server (`hass_mcp`).
- 🚀 **Geführtes Onboarding**:
  - Responsive Status- und Onboarding-Weboberfläche für Ersteinrichtung.
  - Ausgabe der Sign-In URL im Add-on Log.
- 🔒 **Persistente Datenspeicherung**: Sichere Speicherung aller Tokens, Einstellungen und Sitzungen im `/data`-Volume.
- 📂 **Voller Zugriff auf `/config`**: Antigravity kann Home Assistant Automationen, Scripts und Konfigurationen direkt einsehen und bearbeiten.
