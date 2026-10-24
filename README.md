# jlc-tools

Small scripts for ordering KiCad boards from JLCPCB with assembly: part lookup, a stock check for a BOM, and the
Gerber, BOM and placement files. Plain Python standard library plus KiCad's `pcbnew`; no install step. Meant to be added
to board projects as a git submodule, so each board keeps the tool version it was ordered with.

```sh
git submodule add https://github.com/johonkanen/jlc-tools.git tools/jlc
# after cloning a project that uses it:
git submodule update --init
```

## Scripts

| Script | Runs under | What it does |
|---|---|---|
| `jlc_search.py` | any `python3` | Looks up keywords or C-numbers in JLC's assembly library: library type (basic/extended), orderable quantity, minimum purchase, package, MPN |
| `stock_check.py` | any `python3` | Checks every LCSC number in a JLC BOM against the orderable stock for N boards |
| `jlc_bom_cpl.py` | KiCad's Python (`pcbnew`) | Writes the JLC BOM and CPL from a board, with CPL rotations in JLC's convention |
| `fab_outputs.sh` | shell | Runs DRC, exports Gerbers and drill files (zipped), and calls `jlc_bom_cpl.py` |

```sh
python3 -I tools/jlc/jlc_search.py AP61102 C5224055 -n 5
python3 -I tools/jlc/stock_check.py hardware/fab/bom_jlcpcb.csv --boards 10
KICAD_ROOT=<squashfs-root> tools/jlc/fab_outputs.sh hardware/board.kicad_pcb hardware/fab --skip J1,J2
```

`KICAD_ROOT` points to an unpacked KiCad AppImage (`--appimage-extract`). Without it, `fab_outputs.sh` uses
`kicad-cli` and `python3` from `PATH`, which works with a distribution KiCad whose `pcbnew` module is importable.

## Notes

- **Judge stock by the orderable quantity** (`canPresaleNumber`, shown as `free`) and the minimum purchase
  (`minPurchaseNum`), not `stockCount`: the stock count includes parts already reserved by other orders, so a part can
  show stock and still be oversold.
- **BOM and CPL:** footprints marked DNP or "exclude from BOM", footprints without pads, and the `--skip` references
  are left out of both files. Parts without an `LCSC` field stay in the BOM with an empty LCSC column, for Global
  Sourcing or consigned parts. The BOM comment is the `MPN` field when there is one, otherwise the value.
- **Rotations:** bottom-side parts are written as seen from below (180° − angle), plus the usual per-package offsets
  (the table from kicad-jlcpcb-tools / JLCKicadTools). A footprint field `JLC Rotation Offset` overrides the table for
  one part. Always check JLC's placement preview.
- The search uses JLC's public web API, which is undocumented and may change.

## License

[MIT](LICENSE).
