#!/bin/sh
# JLCPCB order files from a KiCad board:
#   <board>_gerbers.zip   Gerbers (all copper layers, mask, paste, silk, edge) + Excellon drill (PTH/NPTH)
#   bom_jlcpcb.csv, cpl_jlcpcb.csv   assembly BOM and placement (jlc_bom_cpl.py)
#   drc.rpt               DRC with the board's own rules (and schematic parity when the .kicad_sch is next to it)
#
# Usage: fab_outputs.sh board.kicad_pcb out_dir [jlc_bom_cpl.py args, e.g. --skip J1,J2]
# out_dir is deleted and recreated. Read-only on the board: zones are refilled for plotting only.
# KICAD_ROOT: an unpacked KiCad AppImage (squashfs-root). Unset: kicad-cli and python3 (with pcbnew) from PATH.
set -e
[ $# -ge 2 ] || { sed -n '2,9p' "$0"; exit 2; }
HERE=$(cd "$(dirname "$0")" && pwd)
PCB=$1
OUT=$2
shift 2
if [ -n "$KICAD_ROOT" ]; then
    CLI="$KICAD_ROOT/AppRun kicad-cli"
    PY="$KICAD_ROOT/AppRun python3.11 -I"
else
    CLI=kicad-cli
    PY="python3 -I"
fi
NAME=$(basename "$PCB" .kicad_pcb)
PARITY=
[ -f "${PCB%.kicad_pcb}.kicad_sch" ] && PARITY=--schematic-parity
N=$($PY -c "import sys, pcbnew; print(pcbnew.LoadBoard(sys.argv[1]).GetCopperLayerCount())" "$PCB")
CU=F.Cu
i=1
while [ $i -le $((N - 2)) ]; do CU="$CU,In$i.Cu"; i=$((i + 1)); done
CU="$CU,B.Cu"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
rm -rf "$OUT"
mkdir -p "$OUT" "$T/gerber"
OUT=$(cd "$OUT" && pwd)
$CLI pcb drc --refill-zones $PARITY -o "$OUT/drc.rpt" "$PCB" | grep Found || true
$CLI pcb export gerbers --check-zones --subtract-soldermask -o "$T/gerber" \
    --layers "$CU,F.Paste,B.Paste,F.SilkS,B.SilkS,F.Mask,B.Mask,Edge.Cuts" "$PCB" > /dev/null
$CLI pcb export drill --format excellon --excellon-units mm --excellon-zeros-format decimal \
    --excellon-separate-th -o "$T/gerber/" "$PCB" > /dev/null
(cd "$T/gerber" && python3 -c "import sys, zipfile, os; z = zipfile.ZipFile(sys.argv[1], 'w', zipfile.ZIP_DEFLATED); [z.write(f) for f in sorted(os.listdir('.'))]" "$OUT/${NAME}_gerbers.zip")
ls "$T/gerber"
$CLI pcb export pos --format csv --units mm --side both -o "$T/pos.csv" "$PCB" > /dev/null
$PY "$HERE/jlc_bom_cpl.py" "$PCB" "$T/pos.csv" "$OUT" "$@"
echo "files in $OUT"
