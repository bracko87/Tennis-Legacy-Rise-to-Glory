#!/usr/bin/env python3
"""Extract the literal security-hardening SQL from the unreleased jet migration.

Outputs only the block after SECURITY BOUNDARY and before defensive compatibility.
Used with a disposable database; never connects to Supabase.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
source = (root / "supabase/migrations/20261026094500_private_life_jet_travel_integration_v1.sql").read_text(encoding="utf8")
begin = source.index("-- SECURITY BOUNDARY:")
end = source.index("-- Defensive compatibility:", begin)
block = source[begin:end]
if block.lower().count("revoke all on function") != 7:
    raise RuntimeError("Expected seven privileged travel helpers to be explicitly locked down.")
print(block)
