"""Reads a `uiautomator dump` of the screen (app exploration, separate from scripts/).

  ui_nodes.py <dump.xml> top                 package of the screen
  ui_nodes.py <dump.xml> texts               the screen's texts, " | " separated
  ui_nodes.py <dump.xml> sig                 a short signature of the screen (package + texts)
  ui_nodes.py <dump.xml> targets             clickable things, one per line: "x y<TAB>label"
Prints nothing (exit 1) when the dump cannot be read.
"""
import hashlib
import re
import sys
import xml.etree.ElementTree as ET

# Never tapped while exploring: money, accounts, destructive or outside actions.
SKIP = re.compile(r"\b(pay|payment|buy|purchase|subscribe|subscription|upgrade|premium|pro version|checkout|donate|"
                  r"delete|remove|uninstall|erase|reset|log ?out|sign ?out|deactivate|call|dial|sms|report|"
                  r"rate us|rate app|share|send feedback)\b", re.I)


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
    else:
        sys.exit(f"unknown: {what}")


main()
