"""Three style directions for Folio's avatars (Batch I, Part 2). Renders sample SVGs only;
the chosen direction is finished in generate.py. No filters (iOS asset-catalog SVGs don't
support them): depth comes from gradients and translucent shapes."""
import os, sys

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

PALETTES = [  # (bg light, bg deep, body, shade, accent)
    ("#FFE3D3", "#FFB38F", "#FFF8F2", "#F6C9AE", "#F0602A"),  # ember
    ("#DCE9FF", "#A9C6FF", "#F7FAFF", "#C3D6F7", "#3D7BFF"),  # ocean
    ("#EADCFF", "#D9B8FF", "#FBF7FF", "#DCC8F2", "#8E4BE0"),  # violet
    ("#DDF3E6", "#A8DDBC", "#F7FDF9", "#C2E3CF", "#2FA35A"),  # sage
    ("#FFF1C9", "#F5D27A", "#FFFCF2", "#F0DDA8", "#C98A0B"),  # sand
    ("#E4E4EA", "#B9BAC6", "#FAFAFC", "#D3D4DC", "#3A3B48"),  # graphite
]

def svg(body, size=256):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="{size}" height="{size}">{body}</svg>'

def bg(i, p):
    return (f'<defs><radialGradient id="bg{i}" cx="35%" cy="25%" r="85%"><stop offset="0" stop-color="{p[0]}"/>'
            f'<stop offset="1" stop-color="{p[1]}"/></radialGradient></defs><circle cx="128" cy="128" r="128" fill="url(#bg{i})"/>')

def eyes(kind, y, color="#2A2230", dx=22):
    if kind == "dots":
        return f'<circle cx="{128-dx}" cy="{y}" r="7" fill="{color}"/><circle cx="{128+dx}" cy="{y}" r="7" fill="{color}"/>'
    if kind == "happy":
        return (f'<path d="M{128-dx-8} {y+3} q8 -10 16 0" stroke="{color}" stroke-width="5" fill="none" stroke-linecap="round"/>'
                f'<path d="M{128+dx-8} {y+3} q8 -10 16 0" stroke="{color}" stroke-width="5" fill="none" stroke-linecap="round"/>')
    return (f'<path d="M{128-dx-8} {y} q8 8 16 0" stroke="{color}" stroke-width="5" fill="none" stroke-linecap="round"/>'
            f'<circle cx="{128+dx}" cy="{y}" r="7" fill="{color}"/>')

# A — Page spirits: a little page with a folded corner, a face, ember cheeks.
def direction_a(i, p, eye):
    return svg(bg(i, p) +
        f'<ellipse cx="128" cy="214" rx="58" ry="10" fill="#000" opacity="0.08"/>'
        f'<path d="M78 70 h70 l30 30 v100 a16 16 0 0 1 -16 16 h-84 a16 16 0 0 1 -16 -16 v-114 a16 16 0 0 1 16 -16z" fill="{p[2]}"/>'
        f'<path d="M148 70 l30 30 h-22 a8 8 0 0 1 -8 -8z" fill="{p[3]}"/>'
        + eyes(eye, 138) +
        f'<circle cx="94" cy="160" r="7" fill="{p[4]}" opacity="0.55"/><circle cx="162" cy="160" r="7" fill="{p[4]}" opacity="0.55"/>'
        f'<circle cx="190" cy="62" r="11" fill="{p[4]}"/>')

# B — Ember sprites: a glowing round spirit inside its own aura rings.
def direction_b(i, p, eye):
    return svg(bg(i, p) +
        f'<defs><radialGradient id="g{i}" cx="40%" cy="35%" r="70%"><stop offset="0" stop-color="#FFFFFF"/>'
        f'<stop offset="0.55" stop-color="{p[2]}"/><stop offset="1" stop-color="{p[3]}"/></radialGradient></defs>'
        f'<circle cx="128" cy="134" r="92" fill="#FFFFFF" opacity="0.18"/><circle cx="128" cy="134" r="76" fill="#FFFFFF" opacity="0.22"/>'
        f'<path d="M128 70 c40 0 62 30 62 66 c0 34 -26 58 -62 58 c-36 0 -62 -24 -62 -58 c0 -36 22 -66 62 -66z" fill="url(#g{i})"/>'
        f'<path d="M128 58 c6 10 6 18 0 26 c-6 -8 -6 -16 0 -26z" fill="{p[4]}"/>'
        + eyes(eye, 136, dx=20))

# C — Fold marks: abstract origami faces built only from page folds and the ember dot.
def direction_c(i, p, eye):
    return svg(bg(i, p) +
        f'<path d="M64 84 L128 60 L192 84 L192 176 L128 200 L64 176z" fill="{p[2]}"/>'
        f'<path d="M128 60 L192 84 L192 176 L128 200z" fill="{p[3]}" opacity="0.7"/>'
        f'<path d="M64 84 L128 108 L192 84" fill="none" stroke="{p[3]}" stroke-width="3"/>'
        f'<circle cx="104" cy="132" r="8" fill="#2A2230"/><rect x="142" y="128" width="20" height="8" rx="4" fill="#2A2230"/>'
        f'<circle cx="128" cy="170" r="9" fill="{p[4]}"/>')

EYES = ["dots", "happy", "wink", "dots", "happy", "wink"]
for name, fn in [("a", direction_a), ("b", direction_b), ("c", direction_c)]:
    for i, p in enumerate(PALETTES):
        open(os.path.join(OUT, f"{name}-{i}.svg"), "w").write(fn(f"{name}{i}", p, EYES[i]))

html = ['<html><body style="margin:0;background:#F5F3EF;font-family:-apple-system">']
for name, title in [("a", "A · Page spirits"), ("b", "B · Ember sprites"), ("c", "C · Fold marks")]:
    html.append(f'<div style="padding:20px 28px 4px;font-size:28px;font-weight:700;color:#16161A">{title}</div><div style="display:flex;gap:18px;padding:8px 28px 18px">')
    for i in range(6):
        html.append(f'<img src="{name}-{i}.svg" width="150" height="150">')
    html.append('</div>')
html.append('</body></html>')
open(os.path.join(OUT, "directions.html"), "w").write("".join(html))
