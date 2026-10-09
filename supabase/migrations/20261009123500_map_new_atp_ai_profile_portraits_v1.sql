-- Map newly uploaded ATP AI profile portraits to the matching AI player records.
-- Mapping is name-based because the supplied list numbers are current ranking positions,
-- while players.ai_profile_number is a separate stable identifier.
-- Jamal Joseph is intentionally omitted because no matching uploaded portrait exists yet.

with supplied(full_name) as (
  values
  ('Hassan Al Doseri'),('Mykola Bondarenko'),('Bjarni Gudmundsson'),('Ilya Sokolov'),
  ('Ibrahima Ndiaye'),('Diego Quesada'),('Bao Tran'),('Noam Cohen'),('Bilal Ahmed'),
  ('Viktor Mikhailov'),('Diego Mamani'),('Kwame Mensah'),('Ahmed El-Tayeb'),('Luis Rosario'),
  ('Marko Vukcevic'),('Cian Murphy'),('Selim Kaya'),('Mateus Manuel'),('Paolo Reyes'),
  ('Arben Krasniqi'),('Lukas Buchel'),('Janis Ozols'),('Arman Sargsyan'),('Emre Yilmaz'),
  ('Amir Hakim'),('Maksim Kavalchuk'),('Andrei Rusu'),('Minh Nguyen'),('Khalid Al-Hinai'),
  ('Giorgi Beridze'),('Anton Lebedev'),('Einar Jonsson'),('Joao Viegas'),('Dinesh Fernando'),
  ('Faisal Al-Sabah'),('Dario Clarke'),('Kieron Baptiste'),('Luc Weber'),('Alain Moukoko'),
  ('Oleksandr Kovalenko'),('Kevin Ramdass'),('Carlos Salazar'),('Issa Abdou'),('Jone Ratu'),
  ('Tendai Moyo'),('Miguel Santos'),('Carlos Mejia'),('Kirill Volkov'),('Amir Hosseini'),
  ('Luca Belluzzi'),('Omar Al-Khatib'),('Marc Pujol'),('Nimal Perera'),('Mantas Kazlauskas'),
  ('Rahim Uddin'),('Sione Maafu'),('Matthew Borg'),('Serge Njoya'),('Brian Okello'),
  ('Joao Mucavele'),('Marios Nicolaou'),('Luis Mendoza'),('Santiago Benitez'),('Samuel Tesfaye'),
  ('Chanda Phiri'),('Jean Pierre'),('Fajar Santoso'),('Marcus Lim'),('Andre Campbell'),
  ('Yacine Bensaid'),('Kossi Agbo'),('Moussa Traore'),('Kabelo Molefe'),('Rafael Rojas'),
  ('Christos Ioannou'),('Abdullah Al-Hakimi'),('Diego Castillo'),('Dawit Bekele'),
  ('Dmitri Morozov'),('Andre Persaud'),('Pavel Fedorov'),('Rizky Pratama'),('Erion Kola'),
  ('Ethan Tan'),('Eitan Levi'),('Elvin Mammadov'),('Juma Msuya'),('Karim Haddad'),('Mert Demir'),
  ('Ahmed Rasheed'),('Javier Valdes'),('Andrii Melnyk'),('Nikola Radovic'),('Karl Tamm'),
  ('Mamadu Balde'),('Nasser Al-Kuwari'),('Andrei Kuznetsov'),('Arben Hoxha'),('Martins Berzins'),
  ('Davit Petrosyan'),('Rustam Rahmonov'),('Daniel Lim'),('Pavel Hryshkevich'),('Kerem Aydin'),
  ('Bat-Erdene Ganbold'),('Koffi Kouassi'),('Taras Shevchuk'),('Hamza Khan'),('Mateo Cevallos'),
  ('Quang Le'),('Adrian Dela Cruz'),('Luan Berisha'),('Maxim Orlov'),('Aron Sigurdsson'),
  ('Fahad Al-Qahtani'),('Oisin Kelly')
)
update public.players p
set
  image_path = 'ATP AI Profils/' || s.full_name || '.png',
  updated_at = now()
from supplied s
where p.world='ATP'
  and p.player_type='ai'
  and lower(concat_ws(' ',p.first_name,p.last_name))=lower(s.full_name)
  and exists (
    select 1
    from storage.objects o
    where o.bucket_id='Admin'
      and o.name=('ATP AI Profils/' || s.full_name || '.png')
  );
