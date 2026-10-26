#!/usr/bin/env python3
"""Extract the unchanged actual booked-flight and travel-day procedures.

The functions are executed against a disposable synthetic PostgreSQL instance.
No connection to a paid or live Supabase project is used.
"""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
src=(root/"supabase/migrations/20261026094500_private_life_jet_travel_integration_v1.sql").read_text(encoding="utf-8")
low=src.lower()
for name in ("insert_planned_travel_leg_v1","process_travel_leg_v1"):
    start=low.index("create or replace function public."+name+"(")
    end=low.index("\n$function$\n;",start)+len("\n$function$\n;")
    print(src[start:end].strip()+"\n")
