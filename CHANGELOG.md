# Changelog · foxtrot-vivado-2024

This file follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/)
and [Semantic Versioning 2.0](https://semver.org).

## [Unreleased]
<!-- Add new entries above this line -->

---

## [0.1.0] – 2025-07-30
### Added
- Vivado 2024.2 back-end implementing the Foxtrot five-verb contract:
  - TCL helpers for project setup, constraints, build flow, netlist & placement export.
  - Wine toggle for running Windows Vivado under Linux.
- Python entry-point `vivado_2024 = foxtrot_vivado_2024.eda_plugin:VivadoPlugin`.
- Hatch build config with bundled TCL assets.

### Compatibility
- Requires **foxtrot-core ≥ 0.1.0**.
