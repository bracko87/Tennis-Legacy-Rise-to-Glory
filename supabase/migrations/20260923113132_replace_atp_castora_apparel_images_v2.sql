-- Replace ATP Castora apparel images with the newly supplied versions.

with supplied_images(sku,image_url) as (
  values
    ('APP-CASTORA-01','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20ATP/Castora%20Apex%20Court%2017%202.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgQVRQL0Nhc3RvcmEgQXBleCBDb3VydCAxNyAyLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAxNjI4NzUsImV4cCI6NDkxMjIyNjg3NX0.kB_Bwyta3jxsqTEk3JppOdsoqnJhwN_4n71W1YR5Kh_Rgr3fAlprfMPvl9blufgEwCReNm7Bx0pAYOMQUF0g-g'),
    ('APP-CASTORA-02','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20ATP/Castora%20Velocity%20Grid%20420%202.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgQVRQL0Nhc3RvcmEgVmVsb2NpdHkgR3JpZCA0MjAgMi5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMTYyODY0LCJleHAiOjQ5MTIyMjY4NjR9.Uc2C-Ex1PNN8EY36_4ya53allEciifUNF3vglh2zhHHafS6ye2d7LOGPMehRkSuhUBPEdOMRLFIR0JLI1XkxhA'),
    ('APP-CASTORA-03','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20ATP/Castora%20Flowstrike%209%202.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgQVRQL0Nhc3RvcmEgRmxvd3N0cmlrZSA5IDIucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDE2MjgzOSwiZXhwIjo0OTEyMjI2ODM5fQ.Y0wxl631YJQwff8F4Yu3-1m3VwEaq3PUA6z-2ZoYAg2XlApIfGA3qOekPGWSZMJeWfIdf2jFNK7Tg5IqU0FF-A'),
    ('APP-CASTORA-04','https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20ATP/Castora%20Northline%20Elite%202.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgQVRQL0Nhc3RvcmEgTm9ydGhsaW5lIEVsaXRlIDIucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDE2Mjg1NCwiZXhwIjo0OTEyMjI2ODU0fQ.62ySOSima46rK7RYCbZd6s_kRBynX08E7YjQIeXwu6L1NdGCmJeGiWm1Rub10ca2DS52oTK-9UIw-f_cj8LQng')
)
update public.equipment_catalog_items c
set image_url=s.image_url
from supplied_images s
where c.sku=s.sku
  and c.item_type='apparel'
  and c.brand='Castora'
  and c.tour_scope='ATP'
  and c.is_active=true
  and c.availability_status='available';
