insert into public.notification_catalog(
  code,category,label,reason,trigger_event,trigger_condition,trigger_mechanism,source_name,title_template,message_template,default_route,severity,default_in_app,default_email,default_push,is_user_configurable,is_active,updated_at
) values
(
  'travel.arrived','travel','Travel completed','Inform the player when a scheduled journey is completed and arrival fatigue/location changes are applied.','travel_leg_processed','A planned player_travel_legs row changes to completed.','Server-side travel engine calls emit_notification_v1 after applying fatigue and updating player_location_state.','Travel Engine','Travel completed','You arrived at your destination. Travel fatigue has been applied.','/game/schedule','info',true,false,false,true,true,now()
),
(
  'travel.planned','travel','Travel planned','Inform the player when future travel is scheduled from tournament or training-camp commitments.','travel_plan_rebuilt','A future route is created or recalculated from player commitments.','Travel itinerary planner creates player_travel_legs rows.','Travel Engine','Travel planned','Your travel itinerary has been updated.','/game/schedule','info',true,false,false,true,true,now()
)
on conflict(code) do update set
  category=excluded.category,label=excluded.label,reason=excluded.reason,trigger_event=excluded.trigger_event,trigger_condition=excluded.trigger_condition,trigger_mechanism=excluded.trigger_mechanism,source_name=excluded.source_name,title_template=excluded.title_template,message_template=excluded.message_template,default_route=excluded.default_route,severity=excluded.severity,is_active=true,updated_at=now();