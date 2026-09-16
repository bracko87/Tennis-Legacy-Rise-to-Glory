-- Refresh the signed Storage URL for Yonnex E-Zen 100 so the UI can load the uploaded PNG.
update public.equipment_catalog_items
set image_url = 'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Recquets/Yonnex%20E-Zen%20100.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9SZWNxdWV0cy9Zb25uZXggRS1aZW4gMTAwLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3ODk1Njk1OTAsImV4cCI6NDkxMTYzMzU5MH0.QMHLMrSp8hIdvfyY5J5UzJwICesmW8pxd-YT2iL_8qRv6uVMFaOjZCpmwV3k83JvhOJhmpEY2wL6ELDXFdz_0g'
where sku = 'RKT-YONNEX-01'
  and brand = 'Yonnex'
  and model = 'E-Zen 100';
