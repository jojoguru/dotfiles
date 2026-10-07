#!/usr/bin/env python3
"""Sichert bzw. übernimmt ausgewählte cmux-Einstellungen aus den macOS-Defaults.

cmux speichert einen Teil der Settings-UI nicht in cmux.json, sondern in den
UserDefaults (Domain com.cmuxterm.app). Ins Repo kommt nur eine Whitelist von
Darstellungs-Keys, keine IDs, Fensterpositionen, Telemetrie- oder Auth-Daten.

  cmux_defaults.py export <datei.plist>   aktuelle Werte -> Datei
  cmux_defaults.py import <datei.plist>   Werte aus Datei in die Defaults mergen
"""

import plistlib
import subprocess
import sys

DOMAIN = "com.cmuxterm.app"

KEYS = [
    # Tab-Markierung nutzt den macOS-Akzent; Graphit statt Blau, nur für cmux
    "AppleAccentColor",
    "AppleAquaColorVariant",
    "appAccentColor",
    "appAccentColorCustomHex",
    "appearanceMode",
    "notificationPaneFlashColorHex",
    "sidebarActiveTabIndicatorStyle",
    "sidebarAppearanceDefaultsVersion",
    "sidebarBlendMode",
    "sidebarBlurOpacity",
    "sidebarCornerRadius",
    "sidebarMaterial",
    "sidebarNotificationBadgeColorHex",
    "sidebarPreset",
    "sidebarSelectionColorHex",
    "sidebarShowAgentUsage",
    "sidebarShowLog",
    "sidebarSubtleSelection",
    "sidebarTintHex",
    "sidebarTintOpacity",
    "workspaceTabColor.colors",
]


def read_domain():
    out = subprocess.run(["defaults", "export", DOMAIN, "-"], capture_output=True)
    if out.returncode != 0 or not out.stdout:
        return {}
    return plistlib.loads(out.stdout)


def export(path):
    current = read_domain()
    picked = {k: current[k] for k in KEYS if k in current}
    with open(path, "wb") as f:
        plistlib.dump(picked, f, sort_keys=True)


def import_(path):
    with open(path, "rb") as f:
        wanted = plistlib.load(f)
    merged = read_domain()
    merged.update({k: v for k, v in wanted.items() if k in KEYS})
    subprocess.run(
        ["defaults", "import", DOMAIN, "-"],
        input=plistlib.dumps(merged, fmt=plistlib.FMT_BINARY),
        check=True,
    )


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("export", "import"):
        sys.exit(__doc__)
    (export if sys.argv[1] == "export" else import_)(sys.argv[2])
