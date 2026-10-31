"""Reads a screenshot with Tesseract OCR, for screens uiautomator cannot dump.

  ocr.py <shot.png> find <phrase>|<phrase>...   centre "x y" of the first phrase found on the screen
  ocr.py <shot.png> findin <word> <phrase>      the same, only on the line that also has <word>
  ocr.py <shot.png> text                        the screen's text, one line per line
  ocr.py <shot.png> code                        the pool code (the line above the Enter code button)
Prints nothing (exit 1) when there is no match. Needs the tesseract command.
"""
import re
import subprocess
import sys


def words(png):
    return ocr(png)


def ocr(png):
    tsv = subprocess.run(["tesseract", png, "-", "--psm", "11", "tsv"],
                         capture_output=True, text=True).stdout
    out = []
    for row in tsv.splitlines()[1:]:
        f = row.split("\t")
        if len(f) == 12 and f[11].strip() and float(f[10]) > 30:
            out.append({"t": f[11].strip(), "x": int(f[6]), "y": int(f[7]), "w": int(f[8]), "h": int(f[9])})
    return out


def lines(ws):
    """Words grouped into screen lines (same height band), left to right."""
    rows = []
    for w in sorted(ws, key=lambda w: (w["y"] + w["h"] / 2, w["x"])):
        cy = w["y"] + w["h"] / 2
        for r in rows:
            if abs(r["cy"] - cy) < max(w["h"], r["h"]) * 0.6:
                r["w"].append(w); break
        else:
            rows.append({"cy": cy, "h": w["h"], "w": [w]})
    for r in rows:
        r["w"].sort(key=lambda w: w["x"])
    return rows


def norm(t):
    return re.sub(r"[^a-z0-9]", "", t.lower())


def find(ws, phrases, anchor=None):
    for phrase in phrases.split("|"):
        want = [norm(p) for p in phrase.split() if norm(p)]
        for r in lines(ws):
            if anchor and norm(anchor) not in [norm(w["t"]) for w in r["w"]]:
                continue
            got = [norm(w["t"]) for w in r["w"]]
            for i in range(len(got) - len(want) + 1):
                if got[i:i + len(want)] == want:
                    m = r["w"][i:i + len(want)]
                    x1, y1 = min(w["x"] for w in m), min(w["y"] for w in m)
                    x2, y2 = max(w["x"] + w["w"] for w in m), max(w["y"] + w["h"] for w in m)
                    return f"{(x1 + x2) // 2} {(y1 + y2) // 2}"
    return None


def code(png, ws):
    """The code box sits right above the "New pool code / Enter code" buttons (about 100-250
    pixels higher). Its big spaced-out letters are cut apart by the empty columns between them
    and read one by one (capital letters and digits only)."""
    from PIL import Image
    at = find(ws, "Enter code")
    if not at:
        return None
    y = int(at.split()[1])
    box = Image.open(png).convert("L").crop((100, max(0, y - 250), 980, y - 100))
    path = png + ".box.png"
    box.save(path)
    line = subprocess.run(["tesseract", path, "-", "--psm", "7"], capture_output=True, text=True).stdout
    if "pool" in norm(line):                                     # "No pool yet": no code made
        return None
    ink = box.point(lambda v: 0 if v < 140 else 255)          # dark letters on the light box
    w, h = ink.size
    px = ink.load()
    cols = [any(px[x, yy] == 0 for yy in range(h)) for x in range(w)]
    runs, x = [], 0
    while x < w:
        if cols[x]:
            x0 = x
            while x < w and cols[x]:
                x += 1
            if x - x0 > 3:
                runs.append((x0, x))
        x += 1
    out = ""
    for x0, x1 in runs:
        rows = [yy for yy in range(h) if any(px[xx, yy] == 0 for xx in range(x0, x1))]
        ch = ink.crop((max(0, x0 - 12), max(0, rows[0] - 12), min(w, x1 + 12), min(h, rows[-1] + 13)))
        path = png + ".ch.png"
        ch.save(path)
        t = subprocess.run(["tesseract", path, "-", "--psm", "10", "-c",
                            "tessedit_char_whitelist=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"],
                           capture_output=True, text=True).stdout.strip()
        out += t[:1]
    return out if len(out) >= 4 else None


def main():
    ws = words(sys.argv[1])
    what = sys.argv[2]
    if what == "text":
        print("\n".join(" ".join(w["t"] for w in r["w"]) for r in lines(ws)))
        return
    if what == "find":
        hit = find(ws, sys.argv[3])
    elif what == "findin":
        hit = find(ws, sys.argv[4], sys.argv[3])
    elif what == "code":
        hit = code(sys.argv[1], ws)
    else:
        sys.exit(f"unknown: {what}")
    if not hit:
        sys.exit(1)
    print(hit)


main()
