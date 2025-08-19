"""
foxtrot_vivado_2024.eda_plugin
==============================

Vivado 2024 plug‑in implementing Foxtrot's *six‑verb* contract.
"""
from __future__ import annotations

# std‑lib imports
import shlex
from pathlib import Path
from typing import Any, Dict, Iterable, List

# local imports
from foxtrot_core.bitgen.logging import get_logger
from foxtrot_core.bitgen.plugin.base import PluginBase
from foxtrot_core.bitgen.plugin.pins import PinResolverMixin
from foxtrot_core.bitgen.plugin.tcl import TclMixin

__all__ = ["VivadoPlugin"]

LOG = get_logger(__name__)


class VivadoPlugin(PinResolverMixin, TclMixin, PluginBase):
    """Xilinx Vivado 2024 backend."""

    # ------------------------------------------------------------------ #
    # helpers                                                            #
    # ------------------------------------------------------------------ #
    def _run(self, script: Path, log_name: str, *kv_pairs: str) -> None:
        """Invoke *script* via ``vivado -mode batch`` and capture *log_name*."""
        cmd = [
            str(self.settings.tcl_executable),
            "-mode",
            "batch",
            "-source",
            str(script),
        ]
        if kv_pairs:
            cmd += ["-tclargs", *kv_pairs]

        LOG.debug("vivado cmd: %s", " ".join(shlex.quote(c) for c in cmd))
        self.sh(cmd, log_name=log_name)

    # ------------------------------------------------------------------ #
    # phase 1 · initialisation                                           #
    # ------------------------------------------------------------------ #
    def create_project(  # noqa: D401 – imperative name is fine
        self,
        *,
        part: str,
        top: str,
        hdl_files: Iterable[Path],
    ) -> None:
        """Create project, add *hdl_files* and set *part* / *top*."""
        self._run(
            self.tcl("project_setup"),
            "01_project_setup.log",
            f"project_name={self.fuzzer_name}",
            f"part={part}",
            f"top_entity={top}",
            "files=" + ",".join(str(f) for f in hdl_files),
        )

    def add_constraints(
        self,
        *,
        pins: Dict[str, Any],
        locs: Dict[str, str],
    ) -> None:
        """Apply pin / location constraints – replaces previous ones."""
        resolved = self.resolve_pins(pins)

        if resolved:
            self._run(
                self.tcl("constraints_pins"),
                "02_constraints_pins.log",
                f"project_name={self.fuzzer_name}",
                "pin_mappings=" + ",".join(f"{p}={n}" for p, n in resolved.items()),
            )

        if locs:
            self._run(
                self.tcl("constraints_locs"),
                "03_constraints_locs.log",
                f"project_name={self.fuzzer_name}",
                "location_mappings=" + ",".join(f"{n}={l}" for n, l in locs.items()),
            )

    # ------------------------------------------------------------------ #
    # phase 2 · tool options                                             #
    # ------------------------------------------------------------------ #
    def configure_tool(self) -> None:  # noqa: D401
        """Set Vivado implementation options (optional hook)."""
        self._run(
            self.tcl("tool_options"),
            "04_tool_options.log",
            f"project_name={self.fuzzer_name}",
        )

    # ------------------------------------------------------------------ #
    # phase 3 · build                                                    #
    # ------------------------------------------------------------------ #
    def build(self) -> None:  # noqa: D401
        """Run synthesis, P&R and bitstream generation."""
        self._run(
            self.tcl("run_flow"),
            "05_flow.log",
            f"project_name={self.fuzzer_name}",
        )

    # ------------------------------------------------------------------ #
    # phase 4 · artefacts                                                #
    # ------------------------------------------------------------------ #
    def bitstream(self) -> Path:
        """Return the absolute path to *top_level.bit* produced by Vivado."""
        impl_path = (
            self.out_dir
            / "vivado_project"
            / f"{self.fuzzer_name}.runs"
            / "impl_1"
            / "top_level.bit"
        )
        if impl_path.is_file():
            return impl_path

        try:
            return next(self.out_dir.glob("*.bit"))
        except StopIteration as exc:  # pragma: no cover
            raise FileNotFoundError("Vivado produced no bitstream") from exc

    def netlist(self) -> Path:
        """Run *netlist_export.tcl* and return post‑implementation netlist."""
        self._run(
            self.tcl("netlist_export"),
            "06_netlist.log",
            f"project_name={self.fuzzer_name}",
        )

        try:
            return next(self.out_dir.glob("*_impl.v"))
        except StopIteration as exc:  # pragma: no cover
            raise FileNotFoundError("Vivado produced no post‑impl netlist") from exc

    def placement(self) -> Path:
        """Export BEL, LOC, NET, VALUE CSV and return its path."""
        csv_path = self.out_dir / "placement.csv"
        self._run(
            self.tcl("placement_export"),
            "06_placement_export.log",
            f"project_name={self.fuzzer_name}",
            f"output_file={csv_path}",
        )
        if not csv_path.is_file():
            raise FileNotFoundError("placement.csv not produced")
        return csv_path

    # ------------------------------------------------------------------ #
    # optional helpers                                                   #
    # ------------------------------------------------------------------ #
    def bit_to_cfg(self, bit: Path) -> bytes:
        """Return config‑frame slice from *bit* (byte‑window from part‑settings)."""
        start = self.config.part.cfg_start_byte
        end = self.config.part.cfg_end_byte
        return bit.read_bytes()[start : end + 1]

    @staticmethod
    def cfg_to_offsets(cfg: bytes) -> List[int]:
        """Return indices of bits set to '1' in *cfg*."""
        bitstring = "".join(f"{byte:08b}" for byte in cfg)
        return [idx for idx, bit in enumerate(bitstring) if bit == "1"]
