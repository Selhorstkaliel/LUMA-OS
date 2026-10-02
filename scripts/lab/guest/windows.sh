#!/bin/sh
# SOMENTE LABORATÓRIO. Executado na sessão Plasma do usuário (via asuser.sh) dentro da VM.
# Imprime JSON com o tamanho lógico da tela e as janelas normais e de diálogo (classe, título, geometria).
# Versão avulsa do luma-lab-windows de setup-test-user.sh, para sistemas sem conta de teste (ISO live).
set -eu
js="$(mktemp --suffix=.js)"; tag="lumaq$$"
cat > "$js" <<'JS'
const ws = workspace.windowList().filter(w => (w.normalWindow || w.dialog) && w.resourceClass !== "xwaylandvideobridge").map(w => {
  const g = w.frameGeometry;
  return {cls: w.resourceClass, title: w.caption, dialog: w.dialog, minimized: w.minimized, active: workspace.activeWindow === w,
          x: g.x, y: g.y, w: g.width, h: g.height};
});
print("LUMAQ " + JSON.stringify({screen: {w: workspace.virtualScreenSize.width, h: workspace.virtualScreenSize.height}, windows: ws}));
JS
since="$(date '+%Y-%m-%d %H:%M:%S')"
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$js" "$tag" >/dev/null
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null
sleep 1
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$tag" >/dev/null
rm -f "$js"
journalctl --user --since "$since" -o cat | sed -n 's/^js: LUMAQ //p' | tail -n1
