#!/usr/bin/env python3
"""Extract unchanged jet functions from the actual migration for isolated SQL execution.

No connection to Supabase is used. Other production-dependent routine bodies
in the same migration are not executed by this focused quote test.
"""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
src=(root/"supabase/migrations/20261026094500_private_life_jet_travel_integration_v1.sql").read_text()
low=src.lower()
for name in ("initialize_private_jet_position_v1","quote_private_jet_leg_v1"):
    start=low.index("create or replace function public."+name+"(")
    end=low.index("revoke all on function public."+name+"(",start)
    print(src[start:end].strip()+"\n")
