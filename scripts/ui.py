"""Finds things on the current Android screen from a `uiautomator dump` XML.

  ui.py <dump.xml> text <regex>   centre "x y" of the first node whose text or description matches
  ui.py <dump.xml> edit <n>       centre of the n-th (0-based) text field
  ui.py <dump.xml> password       centre of the first password field
  ui.py <dump.xml> top            package of the screen's first node
Prints nothing (exit 1) when there is no match.
"""
import re
import sys
import xml.etree.ElementTree as ET


def centre(node):
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", node.get("bounds")))
    return f"{(x1 + x2) // 2} {(y1 + y2) // 2}"


def main():
    nodes = list(ET.parse(sys.argv[1]).iter("node"))
    what = sys.argv[2]
    if what == "text":
        rx = re.compile(sys.argv[3], re.I)
        hits = [n for n in nodes if rx.fullmatch(n.get("text", "").strip()) or rx.fullmatch(n.get("content-desc", "").strip())]
    elif what == "edit":
        hits = [n for n in nodes if n.get("class") == "android.widget.EditText"][int(sys.argv[3]):]
    elif what == "password":
        hits = [n for n in nodes if n.get("password") == "true"]
    elif what == "top":
        print(nodes[0].get("package") if nodes else "")
        return
    else:
        sys.exit(f"unknown: {what}")
    if not hits:
        sys.exit(1)
    print(centre(hits[0]))


main()
