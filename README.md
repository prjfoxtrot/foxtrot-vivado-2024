<!-- badges — swap shields.io for GitHub built-ins once infrastructure is live -->

<p align="center">
  <img src="https://raw.githubusercontent.com/prjfoxtrot/prjfoxtrot/main/media/foxtrot.png"
       width="120"
       alt="Foxtrot logo">
</p>
<h1 align="center">Project Foxtrot Vivado 2024.2 Plugin</h1>

<div align="center">

**AMD / Xilinx Vivado 2024.2** Project Foxtrot Plugin.

<!-- CI status 
<a href="https://github.com/prjfoxtrot/foxtrot-vivado-2024/actions/workflows/ci.yml">
  <img src="https://github.com/prjfoxtrot/foxtrot-vivado-2024/actions/workflows/ci.yml/badge.svg" alt="CI status">
</a>
-->

<!-- Release packaging (wheel upload) -->
<a href="https://github.com/prjfoxtrot/foxtrot-vivado-2024/actions/workflows/release-python.yml">
  <img src="https://github.com/prjfoxtrot/foxtrot-vivado-2024/actions/workflows/release-python.yml/badge.svg?" alt="Package & Release status">
</a>

<!-- Code scanning 
<a href="https://github.com/prjfoxtrot/foxtrot-vivado-2024/actions/workflows/codeql-analysis.yml">
  <img src="https://github.com/prjfoxtrot/foxtrot-vivado-2024/actions/workflows/codeql-analysis.yml/badge.svg" alt="CodeQL analysis">
</a>
-->

<!-- Latest tag -->
<a href="https://github.com/prjfoxtrot/foxtrot-vivado-2024/releases">
  <img src="https://img.shields.io/github/v/release/prjfoxtrot/foxtrot-vivado-2024?include_prereleases" alt="Latest release">
</a>

<!-- Licence -->
<a href="LICENSE">
  <img src="https://img.shields.io/badge/License-Apache%202.0-green.svg" alt="License: Apache-2.0">
</a>

</div>

---

## Table of Contents

1. [Requirements](#requirements)
2. [Directory map](#directory-map)
3. [Configuration files](#configuration-files)
4. [Quick start](#quick-start)
5. [TCL script sequence](#tcl-script-sequence)
6. [Helper script contract](#helper-script-contract)
7. [Contributing](#contributing)
8. [Tagging & releases](#tagging--releases)
9. [Versioning](#versioning)
10. [Roadmap](#roadmap)
11. [License](#license)

---

## Requirements

| Component        | Tested / Supported                       | Notes                                                                                            |
| ---------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------ |
| **OS**           | Linux — **Ubuntu 22.04 LTS (x86_64)**    | Development & testing target.                                                                    |
| **Quartus II**   | **9.0 Build 132 Web Edition** (Windows)  | Install separately; configure in `edas/vivado/2024/eda.toml`.                                    |
| **Foxtrot-core** | ≥ 0.1.0                                  | Provides umbrella CLI (`python -m foxtrot_core bitgen …`).                                       |
| **Python**       | 3.9 – 3.12                               | Use a virtual environment.                                                                       |
| **WINE**         | 8.x                                      | Required only when running the Windows Vivado build under Linux.                                 |


---

## Directory map

```text
foxtrot_vivado_2024/
├─ src/foxtrot_vivado_2024/
│  ├─ __init__.py
│  ├─ eda_plugin.py
│  └─ scripts/tcl/
│     ├─ project_setup.tcl
│     ├─ constraints_pins.tcl
│     ├─ constraints_locs.tcl
│     ├─ tool_options.tcl
│     ├─ run_flow.tcl
│     ├─ netlist_export.tcl
│     └─ placement_export.tcl
├─ pyproject.toml
├─ CHANGELOG.md
└─ README.md
```

---
## Configuration files

Foxtrot uses **pointer-style** workspace config:

* `project_settings.toml` (workspace root) contains **pointers**: `active_eda`, `active_part`, `active_fuzzer`, `db_path`.
* EDA/tool settings live in **`edas/<tool>/<ver>/eda.toml`**.
* Part metadata lives in **`parts/<vendor>/<family>/<part>/part.toml`** (+ `pinout.json`; `fabric.json` reserved for future use).
* An optional **override** TOML may temporarily change keys under `[project]`.

### A) `project_settings.toml` (workspace root)

```toml
[project]
active_part   = "parts/amd/artix7/XC7A100TCSG324"
active_eda    = "edas/vivado/2024"
active_fuzzer = "fuzzers/1-generic/1-lc/1-lut/generic-lc-lut-1-cell_mask/script/generic-lc-lut-1-cell_mask.py"
db_path       = "bitstreams.db"
```

### B) `edas/vivado/2024/eda.toml`

```toml
[eda]
plugin          = "vivado_2024"                         # entry-point (foxtrot.plugins)
tcl_executable  = "/opt/Xilinx/Vivado/2024.2/bin/vivado"
use_wine        = false                                 # Vivado Linux build; WINE not needed
wine_executable = "/usr/bin/wine"
```

### C) `parts/<vendor>/<family>/<part>/part.toml`

```toml
[part]
name            = "XC7A100TCSG324"
vendor          = "amd"
pin_definitions = "pinout.json"     # path relative to this folder
fabric_params   = "fabric.json"     # reserved; may be unused today
cfg_start_byte  = 0x156
cfg_end_byte    = 0x3a58b9
```

`pinout.json` carries a vendor-neutral grid of package pins. Example entry:

```json
{ "name": "K17", "behavior": "inout", "X": 10, "Y": 16 }
```

### D) Optional override

```toml
# override.toml
[project]
active_part = "parts/amd/artix7/XC7A100TCSG324"
active_eda  = "edas/vivado/2024"
```

Run with:

```bash
python -m foxtrot_core bitgen run -w /path/to/workspace -o /tmp/override.toml
```

---

## Quick start

> **Heads‑up** The Foxtrot VS Code extension [`prjfoxtrot`](https://github.com/prjfoxtrot/prjfoxtrot) auto‑fetches the correct wheels in normal use. Follow the steps below **only** if you’re contributing to Foxtrot or need the plug‑in before public wheels are available.

### A · Install (from Git)

```bash
python -m venv .venv && source .venv/bin/activate
python -m pip install -U pip

# Core
pip install "foxtrot-core @ git+https://github.com/prjfoxtrot/foxtrot-core.git"

# Vivado plugin
pip install "foxtrot-vivado-2024 @ git+https://github.com/prjfoxtrot/foxtrot-vivado-2024.git"
```

**Verify discovery & workspace wiring**

```bash
# Should list "vivado_2024"
python -m foxtrot_core bitgen plugins

# Validate paths/files (part/EDA/fuzzer/db)
python -m foxtrot_core bitgen doctor -w /path/to/workspace
```

### B · Build the wheel yourself

```bash
# 1 · Clone
mkdir -p ~/dev && cd ~/dev
git clone https://github.com/prjfoxtrot/prjfoxtrot.git
git clone https://github.com/prjfoxtrot/foxtrot-vivado-2024.git
cd foxtrot-vivado-2024

# 2 · Build
python -m venv .venv && source .venv/bin/activate
python -m pip install -U pip build wheel
python -m build --wheel    # dist/foxtrot_vivado_2024-*.whl

# 3 · Bundle into the Foxtrot extension (dev-mode)
cp dist/foxtrot_vivado_2024-*.whl ../prjfoxtrot/plugins-bundled/

# 4 · Launch extension (F5 → “Extension Development Host”)
code ../prjfoxtrot
```


---

## TCL script sequence

1. **`project_setup.tcl`** – project creation, RTL import, part selection
2. **`constraints_pins.tcl`** / **`constraints_locs.tcl`** – pin & placement locks
3. **`tool_options.tcl`** – synthesis & implementation switches
4. **`run_flow.tcl`** – synthesise → opt → place → route → bitstream
5. **`netlist_export.tcl`** – vendor netlist → flattened Verilog
6. **`placement_export.tcl`** – vendor‑agnostic placement CSV

Artefacts and logs appear under the fuzzer’s `output/<timestamp>/`

---

## Helper script contract

| Phase           | TCL helper                             | Plug‑in hook        | Artefacts produced     |
| --------------- | -------------------------------------- | ------------------- | ---------------------- |
| Project setup   | `project_setup.tcl`                    | `create_project()`  | `.xpr`, `.dcp`         |
| Constraints     | `constraints_pins.tcl`                 | `add_constraints()` | `.xdc`                 |
|                 | `constraints_locs.tcl`                 |                     |                        |
| Tool options    | `tool_options.tcl`                     | `configure_tool()`  | updated `.xpr`         |
| Build           | `run_flow.tcl` / `run_guided_flow.tcl` | `build()`           | `.bit`, timing reports |
| Artefact export | `netlist_export.tcl`                   | `netlist()`         | `*_impl.v`             |
|                 | `placement_export.tcl`                 | `placement()`       | `placement.csv`        |

---

## Contributing

1. **Fork & clone**

   ```bash
   git clone https://github.com/<your‑user>/foxtrot-vivado-2024.git
   cd foxtrot-vivado-2024
   git switch -c feat/<topic>          # or fix/<issue‑id>, docs/<area>, …
   ```

2. **Set up the dev tool‑chain** *(one‑liner)*

   ```bash
   python -m venv .venv && source .venv/bin/activate && pip install -e .[dev] && pre-commit install
   ```

3. **Pre‑commit checklist**

   1. Format & lint `ruff check . --fix && black .`
   2. Tests `pytest`
   3. Build wheel `python -m build --wheel`
   4. **Bump version** in `pyproject.toml` if adding a feature or fix.
   5. **Commit** using *Conventional Commits* — `feat(tcl): add guided‑routing flag`, `fix(build): honour $TMP when exporting placement (#17)`.
   6. **Push & open a PR** — GitHub Actions will run lint + wheel build once workflows are enabled.

4. **PR etiquette**

* Keep changes focused and under ≈ 400 LoC when practical.
* Draft PRs are welcome — they trigger CI and invite early feedback.
* Explain **why** the change is needed, not just what it does.

---

## Tagging & releases

| Artefact             | Tag format                   | Example                      |
| -------------------- | ---------------------------- | ---------------------------- |
| Python wheel / sdist | `foxtrot-vivado-2024-vX.Y.Z` | `foxtrot-vivado-2024-v0.2.0` |

1. Cut a release branch: `git switch -c release/foxtrot-vivado-2024-v0.2.0`
2. Update version + `CHANGELOG.md`.
3. Merge → **annotated tag** and push **only** the tag:

   ```bash
   git	tag -a foxtrot-vivado-2024-v0.2.0 -m "foxtrot-vivado-2024 0.2.0"
   git	push origin foxtrot-vivado-2024-v0.2.0
   ```
4. CI uploads the wheel to a published GitHub Release.

---

## Versioning

Follows [Semantic Versioning 2.0](https://semver.org/).

* While < 1.0, **minor** bumps (`0.X.Y`) *may* break APIs.
* From 1.0 onward, only **major** bumps may break APIs.

Upgrade hints live in each `CHANGELOG.md`.

---

## Roadmap

* **End‑to‑end tests** – integrate vendor tools in CI via containerised runners.

---

## License

Foxtrot‑Vivado‑2024 is licensed under the **Apache License 2.0** (SPDX: `Apache‑2.0`). See the repository‑root [`LICENSE`](LICENSE) file for details.
