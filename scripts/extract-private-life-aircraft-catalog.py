#!/usr/bin/env python3
"""Extract the unchanged tournament-aircraft catalog update from the migration.

Used only by disposable PostgreSQL CI; this script never connects to a live DB.
"""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
src=(root/"supabase/migrations/20261026094500_private_life_jet_travel_integration_v1.sql").read_text(encoding="utf-8")
start=src.index("-- APPROVED TOURNAMENT FLEET")
end=src.index("-- An aircraft's physical position",start)
print(src[start:end])
