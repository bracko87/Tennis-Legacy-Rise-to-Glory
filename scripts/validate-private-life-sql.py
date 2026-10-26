#!/usr/bin/env python3
"""Validate the private-life migrations without connecting to any live Supabase database.

Requires pinned pglast==8.7. This is parser-level validation, NOT end-to-end
schema, RLS, or gameplay execution. Run the SQL smoke suite in an isolated DB
before enabling the feature in production.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

from pglast import parse_plpgsql, parse_sql

ROOT = Path(__file__).resolve().parents[1]
FILES = (
    "supabase/migrations/20261026093000_private_life_career_foundation_v1.sql",
    "supabase/migrations/20261026094500_private_life_jet_travel_integration_v1.sql",
    "supabase/migrations/20261026095500_private_life_profile_residence_v1.sql",
    "tests/private_life_career_db_smoke.sql",
)

# A function is delimited by the same $tag$ on both sides. PL/pgSQL uses its
# own grammar; PostgreSQL's top-level SQL parser does not validate those bodies.
FUNC_RE = re.compile(
    r"(?is)\bcreate\s+or\s+replace\s+function\s+"
    r".*?\bas\s+(\$[A-Za-z_0-9]*\$).*?\1"
)

def main() -> int:
    total_statements = 0
    total_routines = 0
    for name in FILES:
        sql = (ROOT / name).read_text(encoding="utf-8")
        try:
            statements = parse_sql(sql)
        except Exception as exc:
            print(f"FAIL PostgreSQL grammar in {name}: {exc}", file=sys.stderr)
            return 1
        total_statements += len(statements)
        routines = list(FUNC_RE.finditer(sql))
        for idx, m in enumerate(routines, start=1):
            fn = m.group(0)
            if not re.search(r"(?i)\blanguage\s+plpgsql\b", fn):
                continue
            try:
                parse_plpgsql(fn)
            except Exception as exc:
                print(f"FAIL PL/pgSQL routine #{idx} in {name}: {exc}", file=sys.stderr)
                return 1
            total_routines += 1
        print(f"PASS {name}: {len(statements)} PostgreSQL statements, "
              f"{sum(bool(re.search(r'(?i)\blanguage\s+plpgsql\b', m.group(0))) for m in routines)} PL/pgSQL routines")
    print(f"PASS total: {total_statements} SQL statements and "
          f"{total_routines} PL/pgSQL routine bodies")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
