-- First WTA apparel image/catalogue batch.
-- Creates separate WTA clothing rows from matching ATP brand templates,
-- preserving economics and gameplay balance while using WTA-only names/images.

with supplied(sku, brand, model, source_sku, sort_order, image_url) as (
  values
    ('APP-WTA-NOIK-01','Noik','CourtMuse 18','APP-NOIK-01',7101,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Noik%20-%20CourtMuse%2018.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL05vaWsgLSBDb3VydE11c2UgMTgucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDA5MDA5NSwiZXhwIjo0OTEyMTU0MDk1fQ.0XtveXRmROj2q4digEM3x05HKZq_Dx5wjpYNqdRvzJ-8S82SvZTYFBqHQ62TBxCM5gqAEW9VIbiQkncjfxzgRQ'),
    ('APP-WTA-NOIK-02','Noik','DriSilk 42','APP-NOIK-02',7102,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Noik%20-%20DriSilk%2042.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL05vaWsgLSBEcmlTaWxrIDQyLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAwOTAxMDgsImV4cCI6NDkxMjE1NDEwOH0.f727dI90P7cUjtthJ2yGo-0FL_EJQ5rDDaI2IGMRSbPjfa55TEorjd4j3xfDyGY9iBY-yxsc1BTBHdaR9U5Kew'),
    ('APP-WTA-NOIK-03','Noik','AeroLuxe X3','APP-NOIK-03',7103,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Noik%20-%20AeroLuxe%20X3.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL05vaWsgLSBBZXJvTHV4ZSBYMy5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMDkwMDY0LCJleHAiOjQ5MTIxNTQwNjR9.MkiK9rZo55PkqAQrQ8vqr5MEC9_zfM3T1cH_yyZGYhrEdHNfZdlkEN1lbyd5Nxv0ceUP25_KBtUfZ8ZRCPYdMA'),
    ('APP-WTA-NOIK-04','Noik','VaporShape 280','APP-NOIK-04',7104,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Noik%20-%20VaporShape%20280.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL05vaWsgLSBWYXBvclNoYXBlIDI4MC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMDkwMTg3LCJleHAiOjQ5MTIxNTQxODd9.xbPRTbmzrwY1uE7G4vYBBk9ySjNXWRXf1RfC5HOZFBQLmNHvcFKSqJd7qFWLa9n3dDyPea5ZKyfuMV3utZYjFw'),
    ('APP-WTA-NOIK-05','Noik','RallyGlow 6','APP-NOIK-05',7105,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Noik%20-%20RallyGlow%206.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL05vaWsgLSBSYWxseUdsb3cgNi5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMDkwMTM1LCJleHAiOjQ5MTIxNTQxMzV9.GYKiKnBbuf3M2AxFrGQu2KkW4fNdMsnyHdWcReQJEuYPW_JsUw3Rt7HXhh7GyJgN9qtLtj8pT_kIIh48qn22kQ'),
    ('APP-WTA-NOIK-06','Noik','SwiftForm 515','APP-NOIK-06',7106,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Noik%20-%20SwiftForm%20515.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL05vaWsgLSBTd2lmdEZvcm0gNTE1LnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAwOTAxNjIsImV4cCI6NDkxMjE1NDE2Mn0.EiLuiFPWypRqDQjnpv6uXoUCBQk2EaoQiYcj8q9CwXOw7hzhE-A74woOngMblZdSehb607DxLk-Au0fl92sBgw'),
    ('APP-WTA-NOIK-07','Noik','AirSculpt X','APP-NOIK-07',7107,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Noik%20-%20AirSculpt%20X.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL05vaWsgLSBBaXJTY3VscHQgWC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMDkwMDc4LCJleHAiOjQ5MTIxNTQwNzh9._teiiFgWFUgH71hPazvA5qCn-nOT8VVUSV5tTYc_olUGWL21O1tWLVs-votKW2QO58tOCyz5vv9YSDfKOMXNHA'),
    ('APP-WTA-NOIK-08','Noik','Premier Ace 760','APP-NOIK-08',7108,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Noik%20-%20Premier%20Ace%20760.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL05vaWsgLSBQcmVtaWVyIEFjZSA3NjAucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDA5MDEyMywiZXhwIjo0OTEyMTU0MTIzfQ._yPK3NSkF77Txl4MK0W8hn84jroJcQQcqWCZgHVBeA3dEWnT0knVN5W0SYr-qUjVb4zEnEsZk8_12ZSu4t45WA'),
    ('APP-WTA-NOIK-09','Noik','SlamAura 12','APP-NOIK-09',7109,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Noik%20-%20SlamAura%2012.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL05vaWsgLSBTbGFtQXVyYSAxMi5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMDkwMTQ5LCJleHAiOjQ5MTIxNTQxNDl9.togLzE5ETVAoshC85T3XgT2iiK2i35kkK3WVg7H94c_W4JA6fQ-cdx53pFYhcGb48kPtRByRH7MIOfGDLjFRgQ'),
    ('APP-WTA-NOIK-10','Noik','TourMuse 1050','APP-NOIK-10',7110,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Noik%20-%20TourMuse%201050.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL05vaWsgLSBUb3VyTXVzZSAxMDUwLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAwOTAxNzcsImV4cCI6NDkxMjE1NDE3N30.V-EJojiXJze3Zuddtzj1MaBgJlIm39g6ZJ-UP94HsqdhpOMYua242oyj73Fl1PYDhBPazFQ_DShPl08c-U374A'),
    ('APP-WTA-ADIDIS-01','Adidis','ClubForm 27','APP-ADIDIS-01',7121,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Adidis%20-%20ClubForm%2027.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FkaWRpcyAtIENsdWJGb3JtIDI3LnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAwODk3NjUsImV4cCI6NDkxMjE1Mzc2NX0.sXBpJYNjnN_zlQv94_4A6YUQpTPUQFFQYXRceb451psHlomoJVi7HEGjEY2K76AD_a6Igjdz53aLrZtDC-csEg'),
    ('APP-WTA-ADIDIS-02','Adidis','Aeroknit 214','APP-ADIDIS-02',7122,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Adidis%20-%20Aeroknit%20214.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FkaWRpcyAtIEFlcm9rbml0IDIxNC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMDg5NzUwLCJleHAiOjQ5MTIxNTM3NTB9.3RONjkD-fzqz5_W1ykrFBnlNvkC4Cr8T9dS4ZlIrtW_35JDYWs-TEYA1ZqA4WVzDFCLbFfk1qnj9k8B5iZJIsg'),
    ('APP-WTA-ADIDIS-03','Adidis','MatchLine 6','APP-ADIDIS-03',7123,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Adidis%20-%20MatchLine%206.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FkaWRpcyAtIE1hdGNoTGluZSA2LnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAwODk4MTksImV4cCI6NDkxMjE1MzgxOX0.PAwR1n4W3CAdZyIQ_Tj2iHlXDiLW2ROvOV6ASV-P_sxTlQKvN_bIsSIToc2p-qv2JwFLvmzTl7ApJyZ56ZgPCQ'),
    ('APP-WTA-ADIDIS-04','Adidis','CourtFrame X8','APP-ADIDIS-04',7124,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Adidis%20-%20CourtFrame%20X8.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FkaWRpcyAtIENvdXJ0RnJhbWUgWDgucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDA4OTc4MSwiZXhwIjo0OTEyMTUzNzgxfQ.1LlCz-eLmtoikYi_PRT_sclivYcm_TszcMOoazEpz-nizrbuPHYdMIZ-0PBHGyChb8OZcdzyvnovYIRURP7q_Q'),
    ('APP-WTA-ADIDIS-05','Adidis','RallyPoint 390','APP-ADIDIS-05',7125,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Adidis%20-%20RallyPoint%20390.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FkaWRpcyAtIFJhbGx5UG9pbnQgMzkwLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAwODk4NTMsImV4cCI6NDkxMjE1Mzg1M30.dpaK5YwRn3wV-BNBFX3RE9YAaDySQiE1HH5t3SZph-80d-KNe8TL-k-hlClRDWnv-IcclR5KJh2afXBnupL7yg'),
    ('APP-WTA-ADIDIS-06','Adidis','ProShape 73','APP-ADIDIS-06',7126,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Adidis%20-%20ProShape%2073.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FkaWRpcyAtIFByb1NoYXBlIDczLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAwODk4NDIsImV4cCI6NDkxMjE1Mzg0Mn0.USdOa86kXnMEbxTk66YHdNWZT90zfT1xhBREEHOps5tfBP96UIcGLKZ2herhdwxBpww2OFYGB44qAn9FofNZUw'),
    ('APP-WTA-ADIDIS-07','Adidis','PrimeWeave 620','APP-ADIDIS-07',7127,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Adidis%20-%20PrimeWeave%20620.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FkaWRpcyAtIFByaW1lV2VhdmUgNjIwLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAwODk4MzEsImV4cCI6NDkxMjE1MzgzMX0.27qfU9iZg_pmpi4m4LUwnV68qTFEEC-1GxDYtU3qj82mi1KrUvjeAFdsUvlMGlKxBT-R9GERd2p3_5WDoBFQIg'),
    ('APP-WTA-ADIDIS-08','Adidis','EliteLine 31','APP-ADIDIS-08',7128,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Adidis%20-%20EliteLine%2031.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FkaWRpcyAtIEVsaXRlTGluZSAzMS5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMDg5Nzk0LCJleHAiOjQ5MTIxNTM3OTR9.Qi6aoxi6oa7-f3QyvugHy50IlThQqgeRNysYd7tYQ5XuTca75XpB8V2CYJABvnT6lBPksskRUcDEH5Mr0WxBbw'),
    ('APP-WTA-ADIDIS-09','Adidis','MajorForm 870','APP-ADIDIS-09',7129,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Adidis%20-%20MajorForm%20870.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FkaWRpcyAtIE1ham9yRm9ybSA4NzAucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDA4OTgwNywiZXhwIjo0OTEyMTUzODA3fQ.qkFHKqNKJaF46iPaUxHKTPmZDkd_8eULSWzL5yVQiZNjuXlMx01GFhftglcmEXx6zJ2Badq02OYep9OueRfL4g'),
    ('APP-WTA-ADIDIS-10','Adidis','TourGrid 1080','APP-ADIDIS-10',7130,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Adidis%20-%20TourGrid%201080.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FkaWRpcyAtIFRvdXJHcmlkIDEwODAucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDA4OTg2MywiZXhwIjo0OTEyMTUzODYzfQ.J9p2TTTMUIWxayheKD1PiCYXlfR7tZ383JvWLIl-ELGf0vqfIAyjvhcs5RADzgUaYu0mCGUbS193F3VXqOWTOg'),
    ('APP-WTA-ARTENGA-01','Artenga','Essential Fit 22','APP-ARTENGA-01',7141,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Artenga%20-%20Essential%20Fit%2022.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FydGVuZ2EgLSBFc3NlbnRpYWwgRml0IDIyLnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAwODk5MDcsImV4cCI6NDkxMjE1MzkwN30.occni1DiCKYhly_P_4q03HmKyI6RQwzLVSFymqI0CHHTPPy-jwBHfWblGm39_yEm8Xt5aNHWAFnEsJTtfG-CoA'),
    ('APP-WTA-ARTENGA-02','Artenga','AirCourt 240','APP-ARTENGA-02',7142,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Artenga%20-%20AirCourt%20240.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FydGVuZ2EgLSBBaXJDb3VydCAyNDAucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDA4OTg5NSwiZXhwIjo0OTEyMTUzODk1fQ.h4BM9xl4FSsYvPrIM_IsbrYNFs7U0uw-zDH3zO4elgNma5M4bIQCHaErOVjb7jaszLejZtdZfpRsNvPDCngYIw'),
    ('APP-WTA-ARTENGA-03','Artenga','MoveLine X6','APP-ARTENGA-03',7143,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Artenga%20-%20MoveLine%20X6.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FydGVuZ2EgLSBNb3ZlTGluZSBYNi5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMDg5OTE3LCJleHAiOjQ5MTIxNTM5MTd9.iEVPX61wpscbKHxsaaK5cZ7R7Y-MRkRu7XfROotg6uN_Wbav8ftntmlLEIeG1C4Q_rl_-09_jdyld-yCLCUgmA'),
    ('APP-WTA-ARTENGA-04','Artenga','MatchOne 510','APP-ARTENGA-04',7144,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Artenga%20-%20MatchOne%20510.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0FydGVuZ2EgLSBNYXRjaE9uZSA1MTAucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDA4OTkyNywiZXhwIjo0OTEyMTUzOTI3fQ.B_9QETS-TNbt0hjh__Fpoy4yeQzc64ahCiXBhwrm7E813RGpOhKex1KfI2iqPEPdYyMVHo3i8Qx7GQiTX2vkhg'),
    ('APP-WTA-AUSTRALIEN-01','Australien','Sydney Bloom','APP-AUSTRALIEN-01',7151,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Australien%20-%20Sydney%20Bloom.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0F1c3RyYWxpZW4gLSBTeWRuZXkgQmxvb20ucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDA4OTk4NSwiZXhwIjo0OTEyMTUzOTg1fQ.N1h7vtYdCHcjKuP_lGxKn4SDLk34pTq2o7RG0r2NPVfsgeU0YYUFn5BK312uQjnOuSbcWVEE24o1M-tNN1d9Vw'),
    ('APP-WTA-AUSTRALIEN-02','Australien','Gold Coast Air','APP-AUSTRALIEN-02',7152,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Australien%20-%20Gold%20Coast%20Air.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0F1c3RyYWxpZW4gLSBHb2xkIENvYXN0IEFpci5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMDg5OTQ5LCJleHAiOjQ5MTIxNTM5NDl9.dzDRkgcpsMxQ2YCVi5j23gelXVBmoiQ_cZePngbvUJ4qS3a7WWs1tKCUHkv6cDY_J4QRV-xlNTxOIc2FFUCsvA'),
    ('APP-WTA-AUSTRALIEN-03','Australien','Southern Flex 44','APP-AUSTRALIEN-03',7153,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Australien%20-%20Southern%20Flex%2044.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0F1c3RyYWxpZW4gLSBTb3V0aGVybiBGbGV4IDQ0LnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAwODk5NzMsImV4cCI6NDkxMjE1Mzk3M30.VQvvICpROY5xYnvJUYVOYmfTSQL5bjijKTDYBiBgoTdvW6T5NGb5m-hSK2UIeX8-Y1sFodqOrbSZae-CMHC2EA'),
    ('APP-WTA-AUSTRALIEN-04','Australien','Melbourne Rose 620','APP-AUSTRALIEN-04',7154,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Australien%20-%20Melbourne%20Rose%20620.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0F1c3RyYWxpZW4gLSBNZWxib3VybmUgUm9zZSA2MjAucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDA4OTk2MSwiZXhwIjo0OTEyMTUzOTYxfQ.ll3E9KEUOTqyH6-aWzP3tsoKjKpjffqIeUJWCOiqqrh54h_o6V-81H01HLDK4Me4QCaWrawd2R5HlcqkJjs7bg'),
    ('APP-WTA-AUSTRALIEN-05','Australien','AUS-W9','APP-AUSTRALIEN-05',7155,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Australien%20-%20AUS-W9.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0F1c3RyYWxpZW4gLSBBVVMtVzkucG5nIiwic2NvcGUiOiJkb3dubG9hZCIsImlhdCI6MTc5MDA4OTkzOCwiZXhwIjo0OTEyMTUzOTM4fQ.1__-w2rk1v1HCqODHavmJbhqa3thZzEDcpUBgNEkRJ5k_afRmUWt7JAW6ee0lLA_0yK4K8p3-n16zsAcxMVbkQ'),
    ('APP-WTA-BJORNBORGA-01','Bjern Borga','Nordic Bloom 56','APP-BJORNBORGA-01',7161,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Bjern%20Borga%20-%20Nordic%20Bloom%2056.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0JqZXJuIEJvcmdhIC0gTm9yZGljIEJsb29tIDU2LnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAwOTAwMTYsImV4cCI6NDkxMjE1NDAxNn0.Dn4HvYzWJrbL2ThlRbcUscEFQkOF8oNkSKtdPktRtC6b8cxaTQc17cdvJp5JMp1b7gRWYKw6x5gbsnTjqnQgYA'),
    ('APP-WTA-BJORNBORGA-02','Bjern Borga','Oslo Air 225','APP-BJORNBORGA-02',7162,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Bjern%20Borga%20-%20Oslo%20Air%20225.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0JqZXJuIEJvcmdhIC0gT3NsbyBBaXIgMjI1LnBuZyIsInNjb3BlIjoiZG93bmxvYWQiLCJpYXQiOjE3OTAwOTAwMjcsImV4cCI6NDkxMjE1NDAyN30.lWribhim0cVM4vD44nAMzpgDdw_jRpTw0IqVqAwh91eNLQYO5egSNMo1pmo567tFJA9eRQBAva2NS4caEBVmrA'),
    ('APP-WTA-BJORNBORGA-03','Bjern Borga','Court Muse X5','APP-BJORNBORGA-03',7163,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Bjern%20Borga%20-%20Court%20Muse%20X5.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0JqZXJuIEJvcmdhIC0gQ291cnQgTXVzZSBYNS5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMDkwMDAxLCJleHAiOjQ5MTIxNTQwMDF9.gKlpIREDigPLXyX39EURHSfRKLIPs_Hp8s0ItFkl6MSUrwQKTi5egeGNL1ghMnxdXQibOaIv4CethbI2o5wNnQ'),
    ('APP-WTA-BJORNBORGA-04','Bjern Borga','Stockholm Elite 710','APP-BJORNBORGA-04',7164,'https://cwfznmroiqcyhfkfcrow.supabase.co/storage/v1/object/sign/Admin/Equpment/Cloths%20WTA/Bjern%20Borga%20-%20Stockholm%20Elite%20710.png?token=eyJraWQiOiJmYWIyM2E5ZS02NDA1LTQxNjUtODVmNC0wNzZjZjA4NDgyYmQiLCJhbGciOiJIUzUxMiJ9.eyJ1cmwiOiJBZG1pbi9FcXVwbWVudC9DbG90aHMgV1RBL0JqZXJuIEJvcmdhIC0gU3RvY2tob2xtIEVsaXRlIDcxMC5wbmciLCJzY29wZSI6ImRvd25sb2FkIiwiaWF0IjoxNzkwMDkwMDM3LCJleHAiOjQ5MTIxNTQwMzd9.212ulSjmU64Gl6s-tn1mtKLa3TtB1K8eUv70Kn5fibejiOzTqUEth7USZDxUM6ltECnywTX3PaWUacXws--mlQ')
),
src as (
  select
    s.*,
    c.item_type,c.surface,c.power,c.control,c.spin,c.comfort,c.traction,c.stability,c.durability,
    c.price_usd,c.tier,c.tags,c.advantages,c.disadvantages,c.maintenance_text,c.lifespan_text,
    c.effect_scope,c.equip_slot,c.is_resellable,c.resale_modifier,c.technical_brand_id,
    c.product_profile,c.gameplay_effects,c.wear_per_match,c.wrong_surface_wear_multiplier,
    c.weather_profile,c.accessory_kind,c.estimated_uses
  from supplied s
  join public.equipment_catalog_items c
    on c.sku=s.source_sku
   and c.item_type='apparel'
   and c.is_active=true
)
insert into public.equipment_catalog_items(
  sku,item_type,brand,model,description,price_usd,tier,surface,power,control,spin,comfort,traction,stability,durability,
  sort_order,is_active,image_url,tags,advantages,disadvantages,maintenance_text,lifespan_text,effect_scope,
  availability_status,equip_slot,is_resellable,resale_modifier,technical_brand_id,product_profile,gameplay_effects,
  wear_per_match,wrong_surface_wear_multiplier,weather_profile,accessory_kind,estimated_uses,tour_scope
)
select
  sku,item_type,brand,model,
  brand || ' ' || model || ' is a WTA performance clothing model with price-scaled match bonuses.',
  price_usd,tier,surface,power,control,spin,comfort,traction,stability,durability,
  sort_order,true,image_url,
  case when 'wta' = any(tags) then tags else tags || array['wta'] end,
  advantages,disadvantages,maintenance_text,lifespan_text,effect_scope,
  'available',equip_slot,is_resellable,resale_modifier,technical_brand_id,product_profile,gameplay_effects,
  wear_per_match,wrong_surface_wear_multiplier,weather_profile,accessory_kind,estimated_uses,'WTA'
from src
on conflict (sku) do update set
  brand=excluded.brand,
  model=excluded.model,
  description=excluded.description,
  price_usd=excluded.price_usd,
  tier=excluded.tier,
  surface=excluded.surface,
  power=excluded.power,
  control=excluded.control,
  spin=excluded.spin,
  comfort=excluded.comfort,
  traction=excluded.traction,
  stability=excluded.stability,
  durability=excluded.durability,
  sort_order=excluded.sort_order,
  is_active=true,
  image_url=excluded.image_url,
  tags=excluded.tags,
  advantages=excluded.advantages,
  disadvantages=excluded.disadvantages,
  maintenance_text=excluded.maintenance_text,
  lifespan_text=excluded.lifespan_text,
  effect_scope=excluded.effect_scope,
  availability_status='available',
  equip_slot=excluded.equip_slot,
  is_resellable=excluded.is_resellable,
  resale_modifier=excluded.resale_modifier,
  technical_brand_id=excluded.technical_brand_id,
  product_profile=excluded.product_profile,
  gameplay_effects=excluded.gameplay_effects,
  wear_per_match=excluded.wear_per_match,
  wrong_surface_wear_multiplier=excluded.wrong_surface_wear_multiplier,
  weather_profile=excluded.weather_profile,
  accessory_kind=excluded.accessory_kind,
  estimated_uses=excluded.estimated_uses,
  tour_scope='WTA';
