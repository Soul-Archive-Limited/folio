#!/usr/bin/env python3
"""Generates iOS asset-catalog colour sets from shared/design-tokens.json (SPEC §3.2).

Run from the repo root after editing the tokens:  python3 scripts/generate-ios-colors.py
"""
import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOKENS = json.loads((ROOT / "shared/design-tokens.json").read_text())
OUT = ROOT / "ios/Folio/Resources/Assets.xcassets/Colors"


def components(hex_value, alpha):
    h = hex_value.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return {"alpha": f"{alpha:.3f}", "red": f"0x{r:02X}", "green": f"0x{g:02X}", "blue": f"0x{b:02X}"}


def entry(hex_value, alpha, appearances):
    item = {"color": {"color-space": "srgb", "components": components(hex_value, alpha)}, "idiom": "universal"}
    if appearances:
        item["appearances"] = appearances
    return item


def colorset(token):
    alpha = token.get("alpha", {"light": 1.0, "dark": 1.0})
    dark = [{"appearance": "luminosity", "value": "dark"}]
    high = [{"appearance": "contrast", "value": "high"}]
    colors = [entry(token["light"], alpha["light"], None), entry(token["dark"], alpha["dark"], dark)]
    if "contrast" in token:
        c = token["contrast"]
        colors += [entry(token["light"], c["light"], high), entry(token["dark"], c["dark"], dark + high)]
    return {"colors": colors, "info": {"author": "xcode", "version": 1}}


def write(name, token):
    folder = OUT / f"{name}.colorset"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "Contents.json").write_text(json.dumps(colorset(token), indent=2) + "\n")


if OUT.exists():
    shutil.rmtree(OUT)
OUT.mkdir(parents=True)
(OUT / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
for name, token in TOKENS["colors"].items():
    write(name, token)
for name, token in TOKENS["categories"].items():
    write("category" + name[0].upper() + name[1:], token)
# App-wide accent colour = ember.
accent = ROOT / "ios/Folio/Resources/Assets.xcassets/AccentColor.colorset"
accent.mkdir(parents=True, exist_ok=True)
(accent / "Contents.json").write_text(json.dumps(colorset(TOKENS["colors"]["ember"]), indent=2) + "\n")
print(f"Wrote {len(TOKENS['colors']) + len(TOKENS['categories'])} colour sets to {OUT.relative_to(ROOT)}")
