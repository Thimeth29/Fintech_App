"""Tiny dependency-free HTML table reader (port of supabase/functions/_shared/fd_parser.ts)."""
from __future__ import annotations

import html as htmllib
import re
from dataclasses import dataclass


def strip_tags(s: str) -> str:
    s = re.sub(r"<br\s*/?>", " ", s, flags=re.I)
    s = re.sub(r"<[^>]+>", " ", s)
    return re.sub(r"\s+", " ", htmllib.unescape(s)).strip()


@dataclass
class Table:
    rows: list[list[str]]
    context: str  # visible text just before the table (its heading)


def extract_tables(html: str) -> list[Table]:
    clean = re.sub(r"<script[\s\S]*?</script>|<style[\s\S]*?</style>|<!--[\s\S]*?-->", "", html, flags=re.I)
    out: list[Table] = []
    prev_end = 0
    for m in re.finditer(r"<table[\s\S]*?</table>", clean, re.I):
        before = strip_tags(clean[max(prev_end, m.start() - 2000):m.start()])
        rows = [[strip_tags(c) for c in re.findall(r"<t[hd][\s\S]*?</t[hd]>", r, re.I)]
                for r in re.findall(r"<tr[\s\S]*?</tr>", m.group(0), re.I)]
        out.append(Table(rows=rows, context=before[-400:]))
        prev_end = m.end()
    return out
