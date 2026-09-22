-- Replace ATP BlokUV apparel images with revised supplied versions.
-- Only image_url is changed.

with supplied(sku, image_url) as (
  values
    ('APP-BLOKUV-01','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20ATP/Blockuv%20-%20Guardian%20Court%202.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgQVRQL0Jsb2NrdXYgLSBHdWFyZGlhbiBDb3VydCAyLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxMDI1NzUsImV4cCI6NDkxMjE2NjU3NX0.AVxhppEQNdo3qCWJWqwtPmXbNCaaknQ32h1Fv50ypFOTdYmIJy9JGMMn-jWN-SK57pme2cPf9DUD8mryupj_YQ'),
    ('APP-BLOKUV-02','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20ATP/Blockuv%20-%20Solar%2011X%202.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgQVRQL0Jsb2NrdXYgLSBTb2xhciAxMVggMi5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTAyNTA4LCJleHAiOjQ5MTIxNjY1MDh9.vZCqsAb_S6rOeSy3G4sPfFXa5WvAj_KbPBkhRaB645lqqz4CbrTpO3C_d_xQywab6JWOOuW5_Jqz9Lkhjp_W-w'),
    ('APP-BLOKUV-03','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20ATP/Blockuv%20-%20Shield%20Pro%20500%202.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgQVRQL0Jsb2NrdXYgLSBTaGllbGQgUHJvIDUwMCAyLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxMDI0ODEsImV4cCI6NDkxMjE2NjQ4MX0.P1dV8DqH1JtUlIjQTTTI-umbUJTvEpVf2oj1uh1SME3wjjCj6147IMCphy4bEeXajiWeAMzEQ8V-wnWQ0JrWAw'),
    ('APP-BLOKUV-04','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20ATP/Blockuv%20-%20SunRush%202.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgQVRQL0Jsb2NrdXYgLSBTdW5SdXNoIDIucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDEwMjUyOCwiZXhwIjo0OTEyMTY2NTI4fQ.RoekKhAHHIc8yPW-YTRntcCM0MqbgDHs-T4_odo6VPwlvTMkHKPQ3bDl95MFqPoh6VHmgxzMm8VavNSChxIYoA'),
    ('APP-BLOKUV-05','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20ATP/Blockuv%20-%20UVX%20300%202.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgQVRQL0Jsb2NrdXYgLSBVVlggMzAwIDIucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDEwMjU0OCwiZXhwIjo0OTEyMTY2NTQ4fQ.CFEjuyC6jtfh5lNPwkk6OC8TNga5YF32GFw7I_GtF6-5-ScGUjH3S2zuEXpNMb17A-fK2Xu5MJrNFC13wlFp-w')
)
update public.equipment_catalog_items c
set image_url = s.image_url
from supplied s
where c.sku = s.sku
  and c.item_type = 'apparel'
  and c.brand = 'BlokUV'
  and c.tour_scope = 'ATP'
  and c.is_active = true;
