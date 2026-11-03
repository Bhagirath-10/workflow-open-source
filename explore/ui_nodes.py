"""Reads a `uiautomator dump` of the screen (app exploration, separate from scripts/).

  ui_nodes.py <dump.xml> top                 package of the screen
  ui_nodes.py <dump.xml> texts               the screen's texts, " | " separated
  ui_nodes.py <dump.xml> sig                 a short signature of the screen (package + texts)
  ui_nodes.py <dump.xml> targets             clickable things, one per line: "x y<TAB>label"
  ui_nodes.py <dump.xml> click <regex>        centre "x y" of the lowest clickable thing whose text
                                             (or a child's text) matches <regex> (the button, not the title)
  ui_nodes.py <dump.xml> edits               centres of the text fields, top to bottom, one per line
  ui_nodes.py <dump.xml> fieldbelow <regex>   centre of the text field right under the label matching <regex>
                                             (or the field whose own hint matches it)
Prints nothing (exit 1) when the dump cannot be read.
"""
import hashlib
import re
import sys
import xml.etree.ElementTree as ET

# Never tapped while exploring: money, accounts, destructive or outside actions.
SKIP = re.compile(r"\b(pay|payment|buy|purchase|subscribe|subscription|upgrade|premium|pro version|checkout|donate|"
                  r"delete|remove|uninstall|erase|reset|log ?out|sign ?out|deactivate|call|dial|sms|report|"
                  r"rate us|rate app|share|send feedback|learn more|install now|open app|visit site|ad choices)\b", re.I)


def nodes(path):
    return list(ET.parse(path).iter("node"))


def label(n):
    t = (n.get("text") or "").strip() or (n.get("content-desc") or "").strip()
    if not t:
        rid = (n.get("resource-id") or "").split("/")[-1]
        t = f"[{rid}]" if rid else f"[{n.get('class', '').split('.')[-1]}]"
    return t[:60]


def centre(n):
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", n.get("bounds", "[0,0][0,0]")))
    return (x1 + x2) // 2, (y1 + y2) // 2, (x2 - x1) * (y2 - y1)


def main():
    try:
        ns = nodes(sys.argv[1])
    except Exception:
        sys.exit(1)
    if not ns:
        sys.exit(1)
    what = sys.argv[2]
    texts = []
    for n in ns:
        t = (n.get("text") or n.get("content-desc") or "").strip()
        if t and t not in texts:
            texts.append(t)
    if what == "top":
        print(ns[0].get("package", ""))
    elif what == "texts":
        print(" | ".join(texts)[:1500])
    elif what == "sig":
        base = ns[0].get("package", "") + "|" + "|".join(sorted(t for t in texts if not re.search(r"\d", t))[:40])
        print(hashlib.sha1(base.encode()).hexdigest()[:12])
    elif what == "targets":
        seen = set()
        for n in ns:
            if n.get("clickable") != "true" or n.get("enabled") == "false":
                continue
            x, y, area = centre(n)
            if area < 400 or y < 60:            # tiny, or the status bar
                continue
            # the label of a clickable container: its own text or its first child with text
            lab = label(n)
            if lab.startswith("["):
                for c in n.iter("node"):
                    t = (c.get("text") or c.get("content-desc") or "").strip()
                    if t:
                        lab = t[:60]
                        break
            if SKIP.search(lab) or (x, y) in seen:
                continue
            seen.add((x, y))
            print(f"{x} {y}\t{lab}")
    elif what == "click":
        rx = re.compile(sys.argv[3], re.I)
        parent = {c: p for p in ns for c in p}
        hits = []
        for n in ns:
            t = (n.get("text") or n.get("content-desc") or "").strip()
            if t and rx.fullmatch(t):
                c = n
                while c is not None and c.get("clickable") != "true":
                    c = parent.get(c)
                hits.append(c if c is not None else n)
        if not hits:
            sys.exit(1)
        x, y, _ = centre(max(hits, key=lambda h: centre(h)[1]))
        print(x, y)
    elif what == "fieldbelow":
        rx = re.compile(sys.argv[3], re.I)
        edits = [n for n in ns if n.get("class") == "android.widget.EditText"]
        for e in edits:                                   # a field whose hint/text is the label
            if rx.fullmatch((e.get("text") or e.get("hint") or "").strip()):
                x, y, _ = centre(e); print(x, y); return
        labels = [centre(n)[1] for n in ns if n.get("class") != "android.widget.EditText"
                  and rx.fullmatch((n.get("text") or n.get("content-desc") or "").strip())]
        best = None
        for ly in labels:
            for e in edits:
                x, y, _ = centre(e)
                if y > ly and (best is None or y - ly < best[2]):
                    best = (x, y, y - ly)
        if best is None or best[2] > 400:
            sys.exit(1)
        print(best[0], best[1])
    elif what == "edits":
        es = sorted((centre(n) for n in ns if n.get("class") == "android.widget.EditText"), key=lambda c: (c[1], c[0]))
        if not es:
            sys.exit(1)
        for x, y, _ in es:
            print(x, y)
    else:
        sys.exit(f"unknown: {what}")


main()
