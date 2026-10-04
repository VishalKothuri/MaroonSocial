alter table social_private.room_members add column if not exists muted_until timestamptz;

create or replace function public.room_preferences(p_action text,p_hash text,p_input jsonb default '{}') returns jsonb
language plpgsql security invoker set search_path='' as $$
declare me uuid; rid text:=p_input->>'room_id'; until_value timestamptz; hours_value integer;
begin
 me:=social_private.require_member(p_hash);
 if not social_private.can_read_room(me,rid) or not exists(select 1 from social_private.room_members where room=rid and member=me and status='accepted') then
  raise exception 'forbidden:Join this conversation before changing notifications.';
 end if;
 if p_action='set' then
  if jsonb_typeof(p_input->'hours') is distinct from 'number' or (p_input->>'hours')!~'^-?[0-9]+$' then raise exception 'invalid:Choose a mute duration.';end if;
  hours_value:=(p_input->>'hours')::integer;
  if hours_value not in(-1,0,1,8,24,168) then raise exception 'invalid:Choose a supported mute duration.';end if;
  until_value:=case when hours_value=0 then null when hours_value=-1 then '9999-01-01T00:00:00Z'::timestamptz else now()+make_interval(hours=>hours_value) end;
  update social_private.room_members set muted_until=until_value where room=rid and member=me and status='accepted';
 elsif p_action<>'get' then raise exception 'invalid:Unknown notification preference.';
 end if;
 select muted_until into until_value from social_private.room_members where room=rid and member=me;
 return jsonb_build_object('muted',coalesce(until_value>now(),false),'muted_until',extract(epoch from until_value));
exception when others then
 if position(':' in sqlerrm)>0 then return jsonb_build_object('error',split_part(sqlerrm,':',2),'code',split_part(sqlerrm,':',1));end if;
 return jsonb_build_object('error','Notification preferences could not be saved.','code','invalid');
end $$;
revoke all on function public.room_preferences(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.room_preferences(text,text,jsonb) to service_role;
