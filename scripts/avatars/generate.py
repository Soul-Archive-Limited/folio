"""Folio avatars (Batch I, Part 2): 24 "page spirits" — little pages with a folded corner,
a face and Folio's ember dot, one per palette and personality. One source of truth for every
platform. Run from the repo root:

    python3 scripts/avatars/generate.py

Writes shared/avatars/*.svg + manifest.json, the iOS asset catalog image sets
(ios/Folio/Resources/Assets.xcassets/Avatars) and web/public/avatars. No SVG filters: iOS
asset-catalog SVGs don't support them, so depth is gradients and translucent shapes."""
import json, os, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHARED = os.path.join(ROOT, "shared", "avatars")
IOS = os.path.join(ROOT, "ios", "Folio", "Resources", "Assets.xcassets", "Avatars")
WEB = os.path.join(ROOT, "web", "public", "avatars")
INK = "#2A2230"

# name: (bg light, bg deep, page, fold/shade, accent) — tuned so the page reads on both themes.
PALETTES = {
    "ember":    ("#FFE6D8", "#FFB08A", "#FFF8F3", "#F5C6AA", "#F0602A"),
    "coral":    ("#FFE2DE", "#FFA99D", "#FFF7F5", "#F4C0B8", "#E5484D"),
    "rose":     ("#FFE0EC", "#F7A8C6", "#FFF7FA", "#F0C2D4", "#D6336C"),
    "plum":     ("#F3DDF3", "#D7A3D9", "#FDF6FD", "#E2C3E3", "#9C3FA0"),
    "violet":   ("#EADFFF", "#C9AEFF", "#FAF7FF", "#D9CBF5", "#7A4DE0"),
    "indigo":   ("#DFE3FF", "#A9B4FF", "#F7F8FF", "#C9CFF5", "#4250D6"),
    "ocean":    ("#DCEBFF", "#9FC4FF", "#F6FAFF", "#C2D7F5", "#2F6FE4"),
    "teal":     ("#D6F3F0", "#92D9D1", "#F4FCFB", "#BCE3DE", "#13897D"),
    "sage":     ("#DDF2E3", "#A3D9B4", "#F6FCF8", "#C3E2CD", "#2F8F52"),
    "olive":    ("#ECF0D3", "#C8D38E", "#FBFCF4", "#DCE1BC", "#6E7F1F"),
    "sand":     ("#FFF1CF", "#F2CF7F", "#FFFCF3", "#EFDDAE", "#B97A0A"),
    "graphite": ("#E5E5EB", "#B4B5C2", "#FAFAFC", "#D2D3DB", "#3A3B48"),
}

# (id, name, palette, page shape, fold side, eyes, mouth, accessory)
AVATARS = [
    (1, "Spark", "ember", "page", "right", "dots", "smile", "spark"),
    (2, "Margin", "ocean", "page", "left", "happy", "none", "ribbon"),
    (3, "Doodle", "violet", "tall", "right", "wink", "smile", "halo"),
    (4, "Pebble", "sage", "card", "right", "sleepy", "none", "leaf"),
    (5, "Sunny", "sand", "wide", "right", "big", "grin", "spark"),
    (6, "Ink", "graphite", "page", "right", "side", "none", "lines"),
    (7, "Bloom", "rose", "page", "left", "happy", "smile", "leaf"),
    (8, "Tide", "teal", "tall", "left", "dots", "o", "halo"),
    (9, "Moss", "olive", "stack", "right", "sleepy", "smile", "spark"),
    (10, "Plume", "plum", "card", "left", "big", "none", "ribbon"),
    (11, "Comet", "indigo", "page", "right", "wink", "grin", "spark"),
    (12, "Ember", "coral", "wide", "left", "dots", "smile", "bobble"),
    (13, "Echo", "ocean", "stack", "left", "side", "smile", "lines"),
    (14, "Clover", "sage", "page", "right", "big", "o", "bobble"),
    (15, "Dusk", "violet", "card", "right", "sleepy", "smile", "halo"),
    (16, "Maple", "ember", "tall", "left", "happy", "grin", "leaf"),
    (17, "Quill", "graphite", "wide", "right", "dots", "none", "ribbon"),
    (18, "Fig", "plum", "page", "right", "happy", "o", "spark"),
    (19, "Ripple", "teal", "card", "left", "wink", "smile", "lines"),
    (20, "Honey", "sand", "stack", "right", "big", "smile", "halo"),
    (21, "Pip", "coral", "tall", "right", "side", "o", "bobble"),
    (22, "Fern", "olive", "page", "left", "dots", "grin", "leaf"),
    (23, "Nova", "indigo", "wide", "left", "happy", "smile", "halo"),
    (24, "Petal", "rose", "card", "right", "sleepy", "none", "ribbon"),
]

SHAPES = {  # x, y, width, height, corner radius, fold size
    "page": (76, 66, 104, 140, 16, 30),
    "tall": (86, 56, 84, 156, 16, 26),
    "wide": (62, 82, 132, 112, 18, 30),
    "card": (72, 72, 112, 128, 30, 24),
    "stack": (80, 70, 98, 134, 16, 28),
}


def page_path(x, y, w, h, r, f, side):
    """A rounded page with one top corner cut for the fold."""
    if side == "right":
        return (f"M{x+r} {y} H{x+w-f} L{x+w} {y+f} V{y+h-r} A{r} {r} 0 0 1 {x+w-r} {y+h} "
                f"H{x+r} A{r} {r} 0 0 1 {x} {y+h-r} V{y+r} A{r} {r} 0 0 1 {x+r} {y} Z")
    return (f"M{x+f} {y} H{x+w-r} A{r} {r} 0 0 1 {x+w} {y+r} V{y+h-r} A{r} {r} 0 0 1 {x+w-r} {y+h} "
            f"H{x+r} A{r} {r} 0 0 1 {x} {y+h-r} V{y+f} Z")


def fold_path(x, y, w, f, side):
    if side == "right":
        return f"M{x+w-f} {y} L{x+w} {y+f} H{x+w-f+6} A6 6 0 0 1 {x+w-f} {y+f-6} Z"
    return f"M{x+f} {y} L{x} {y+f} H{x+f-6} A6 6 0 0 0 {x+f} {y+f-6} Z"


def eyes(kind, cx, y):
    dx = 20
    l, r = cx - dx, cx + dx
    stroke = f'stroke="{INK}" stroke-width="5.5" fill="none" stroke-linecap="round"'
    if kind == "dots":
        return f'<circle cx="{l}" cy="{y}" r="7" fill="{INK}"/><circle cx="{r}" cy="{y}" r="7" fill="{INK}"/>'
    if kind == "happy":
        return f'<path d="M{l-8} {y+3} q8 -11 16 0" {stroke}/><path d="M{r-8} {y+3} q8 -11 16 0" {stroke}/>'
    if kind == "wink":
        return f'<path d="M{l-8} {y} q8 9 16 0" {stroke}/><circle cx="{r}" cy="{y}" r="7" fill="{INK}"/>'
    if kind == "sleepy":
        return f'<path d="M{l-8} {y-1} q8 8 16 0" {stroke}/><path d="M{r-8} {y-1} q8 8 16 0" {stroke}/>'
    if kind == "big":
        return (f'<circle cx="{l}" cy="{y}" r="10" fill="{INK}"/><circle cx="{r}" cy="{y}" r="10" fill="{INK}"/>'
                f'<circle cx="{l+3.5}" cy="{y-3.5}" r="3.4" fill="#FFFFFF"/><circle cx="{r+3.5}" cy="{y-3.5}" r="3.4" fill="#FFFFFF"/>')
    # side: looking to one side
    return f'<circle cx="{l+5}" cy="{y}" r="7" fill="{INK}"/><circle cx="{r+5}" cy="{y}" r="7" fill="{INK}"/>'


def mouth(kind, cx, y):
    stroke = f'stroke="{INK}" stroke-width="4.5" fill="none" stroke-linecap="round"'
    if kind == "smile":
        return f'<path d="M{cx-9} {y} q9 8 18 0" {stroke}/>'
    if kind == "grin":
        return f'<path d="M{cx-11} {y-2} h22 q-2 12 -11 12 q-9 0 -11 -12 z" fill="{INK}"/><path d="M{cx-6} {y+5} q6 4 12 0" stroke="#F0602A" stroke-width="3" fill="none" stroke-linecap="round" opacity="0.9"/>'
    if kind == "o":
        return f'<ellipse cx="{cx}" cy="{y+2}" rx="5" ry="6" fill="{INK}"/>'
    return ""


def accessory(kind, p, shape, side):
    x, y, w, h, r, f = shape
    a = p[4]
    if kind == "spark":  # the ember dot, floating beside the fold
        sx = x + w + 14 if side == "right" else x - 14
        return f'<circle cx="{sx}" cy="{y-6}" r="12" fill="{a}"/><circle cx="{sx-4}" cy="{y-10}" r="4" fill="#FFFFFF" opacity="0.55"/>'
    if kind == "bobble":  # an ember dot on a stalk, like a little antenna
        cx = x + w / 2
        return f'<path d="M{cx} {y} q-4 -14 6 -24" stroke="{a}" stroke-width="5" fill="none" stroke-linecap="round"/><circle cx="{cx+7}" cy="{y-28}" r="10" fill="{a}"/>'
    if kind == "ribbon":  # a bookmark hanging from the bottom edge
        bx = x + w - 30 if side == "left" else x + 22
        return f'<path d="M{bx} {y+h-4} v30 l9 -8 l9 8 v-30 z" fill="{a}"/>'
    if kind == "halo":  # the aura, as a soft ring above
        cx = x + w / 2
        return (f'<ellipse cx="{cx}" cy="{y-18}" rx="34" ry="9" fill="none" stroke="{a}" stroke-width="5" opacity="0.85"/>'
                f'<ellipse cx="{cx}" cy="{y-18}" rx="34" ry="9" fill="none" stroke="#FFFFFF" stroke-width="1.5" opacity="0.6"/>')
    if kind == "leaf":
        lx = x + w - 6 if side == "left" else x + 8
        return (f'<path d="M{lx} {y+4} c-22 -6 -30 -26 -24 -40 c16 4 28 18 24 40 z" fill="{a}"/>'
                f'<path d="M{lx} {y+4} c-8 -10 -14 -22 -22 -36" stroke="#FFFFFF" stroke-width="2" fill="none" opacity="0.6"/>')
    if kind == "lines":  # writing on its tummy
        lx = x + 22
        return "".join(f'<rect x="{lx}" y="{y+h-46+i*12}" width="{w-44-(i*14)}" height="5" rx="2.5" fill="{p[3]}"/>' for i in range(3))
    return ""


def avatar_svg(spec):
    aid, name, palette, shape_name, side, eye, mth, acc = spec
    p = PALETTES[palette]
    shape = SHAPES[shape_name]
    x, y, w, h, r, f = shape
    gid = f"a{aid:02d}"
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256" role="img" aria-label="{name}">',
        f'<defs><radialGradient id="{gid}bg" cx="32%" cy="24%" r="88%"><stop offset="0" stop-color="{p[0]}"/><stop offset="1" stop-color="{p[1]}"/></radialGradient>',
        f'<linearGradient id="{gid}pg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="{p[2]}"/></linearGradient></defs>',
        f'<circle cx="128" cy="128" r="128" fill="url(#{gid}bg)"/>',
        # soft light from the top-left and a ground shadow
        f'<ellipse cx="96" cy="70" rx="90" ry="60" fill="#FFFFFF" opacity="0.18"/>',
        f'<ellipse cx="{x + w/2}" cy="{y + h + 10}" rx="{w*0.55}" ry="9" fill="#000000" opacity="0.09"/>',
    ]
    if acc in ("halo", "bobble") and acc:
        parts.append(accessory(acc, p, shape, side))
    if shape_name == "stack":  # a second page peeking out behind
        parts.append(f'<path d="{page_path(x+16, y-8, w, h, r, f, side)}" fill="{p[3]}" opacity="0.75"/>')
    parts.append(f'<path d="{page_path(x, y, w, h, r, f, side)}" fill="url(#{gid}pg)"/>')
    parts.append(f'<path d="{fold_path(x, y, w, f, side)}" fill="{p[3]}"/>')
    if acc == "lines":
        parts.append(accessory(acc, p, shape, side))
    cx = x + w / 2
    eye_y = y + h * 0.46
    parts.append(eyes(eye, cx, eye_y))
    # cheeks: two soft ember dots
    parts.append(f'<circle cx="{cx-32}" cy="{eye_y+20}" r="7.5" fill="{p[4]}" opacity="0.4"/><circle cx="{cx+32}" cy="{eye_y+20}" r="7.5" fill="{p[4]}" opacity="0.4"/>')
    parts.append(mouth(mth, cx, eye_y + 24))
    if acc in ("spark", "ribbon", "leaf"):
        parts.append(accessory(acc, p, shape, side))
    parts.append("</svg>")
    return "".join(parts)


def main():
    for folder in (SHARED, WEB):
        os.makedirs(folder, exist_ok=True)
    if os.path.isdir(IOS):
        shutil.rmtree(IOS)
    os.makedirs(IOS)
    json.dump({"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}},
              open(os.path.join(IOS, "Contents.json"), "w"), indent=2)
    manifest = []
    for spec in AVATARS:
        aid, name, palette = spec[0], spec[1], spec[2]
        file = f"avatar-{aid:02d}.svg"
        text = avatar_svg(spec)
        for folder in (SHARED, WEB):
            open(os.path.join(folder, file), "w").write(text)
        imageset = os.path.join(IOS, f"avatar-{aid:02d}.imageset")
        os.makedirs(imageset)
        open(os.path.join(imageset, file), "w").write(text)
        json.dump({"images": [{"filename": file, "idiom": "universal"}], "info": {"author": "xcode", "version": 1},
                   "properties": {"preserves-vector-representation": True}},
                  open(os.path.join(imageset, "Contents.json"), "w"), indent=2)
        manifest.append({"id": aid, "key": f"folio:{aid:02d}", "name": name, "palette": palette,
                         "accent": PALETTES[palette][4], "background": PALETTES[palette][1]})
    json.dump(manifest, open(os.path.join(SHARED, "manifest.json"), "w"), indent=2)
    print(f"{len(manifest)} avatars written")


if __name__ == "__main__":
    main()
