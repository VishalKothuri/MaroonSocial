-- Official general-campus final-exam dates bound course chat access and retention.
create table course_private.terms(
 term text primary key,season text not null check(season in('Spring','Summer','Fall')),year int not null check(year between 2000 and 2100),
 opens_at timestamptz not null,ends_on date,closes_at timestamptz,purge_at timestamptz,
 verified boolean not null default false,source_url text not null,end_basis text,source_section text,
 updated_at timestamptz not null default now(),closed_at timestamptz,
 check(term=season||' '||year::text),check(not verified or(ends_on is not null and closes_at>opens_at and purge_at>closes_at))
);
alter table course_private.terms enable row level security;
create policy "Server manages official term dates" on course_private.terms for all to service_role using(true)with check(true);
revoke all on course_private.terms from public,anon,authenticated;
grant select,insert,update on course_private.terms to service_role;
create table course_private.calendar_refresh(id boolean primary key default true check(id),claimed_at timestamptz not null default '-infinity');
insert into course_private.calendar_refresh(id)values(true);
alter table course_private.calendar_refresh enable row level security;
create policy "Server refresh lease" on course_private.calendar_refresh for all to service_role using(true)with check(true);
revoke all on course_private.calendar_refresh from public,anon,authenticated;
grant select,update on course_private.calendar_refresh to service_role;

create function public.claim_course_calendar_refresh()returns boolean language plpgsql security invoker set search_path='' as $$
begin
 update course_private.calendar_refresh set claimed_at=now() where id and claimed_at<now()-interval '1 day';
 return found;
end $$;

create function public.course_calendar_ingest(p_terms jsonb)returns integer language plpgsql security invoker set search_path='' as $$
declare item jsonb; season_value text;year_value int;end_value date;open_value timestamptz;close_value timestamptz;purge_value timestamptz;is_verified boolean;n int:=0;begin
 if jsonb_typeof(p_terms)<>'array' or jsonb_array_length(p_terms)>60 then raise exception 'Invalid calendar payload';end if;
 for item in select value from jsonb_array_elements(p_terms)loop
  season_value:=item->>'season';year_value:=(item->>'year')::int;is_verified:=coalesce((item->>'verified')::boolean,false);
  if season_value not in('Spring','Summer','Fall')or year_value not between 2000 and 2100 or item->>'id'<>season_value||' '||year_value::text then raise exception 'Invalid term';end if;
  if item->>'sourceURL'!~'^https://catalog[.]tamu[.]edu/(archives/[0-9]{4}-[0-9]{4}/)?undergraduate/academic-calendar/$' then raise exception 'Invalid calendar source';end if;
  end_value:=nullif(item->>'endsOn','')::date;
  if is_verified and(end_value is null or extract(year from end_value)<>year_value or extract(month from end_value)<>case season_value when 'Spring'then 5 when 'Summer'then 8 else 12 end or item->>'endBasis'<>'last_final_exam')then raise exception 'Unverified semester ending';end if;
  open_value:=case season_value when 'Spring'then make_timestamptz(year_value-1,12,1,0,0,0,'America/Chicago')when 'Summer'then make_timestamptz(year_value,5,1,0,0,0,'America/Chicago')else make_timestamptz(year_value,8,1,0,0,0,'America/Chicago')end;
  close_value:=case when is_verified then (end_value+1)::timestamp at time zone 'America/Chicago'else null end;
  purge_value:=case when is_verified then ((close_value at time zone 'America/Chicago')+interval '1 month')at time zone 'America/Chicago'else null end;
  insert into course_private.terms(term,season,year,opens_at,ends_on,closes_at,purge_at,verified,source_url,end_basis,source_section)
   values(item->>'id',season_value,year_value,open_value,case when is_verified then end_value end,close_value,purge_value,is_verified,item->>'sourceURL',item->>'endBasis',left(item->>'sourceSection',150))
   on conflict(term)do update set ends_on=excluded.ends_on,closes_at=excluded.closes_at,purge_at=excluded.purge_at,verified=excluded.verified,source_url=excluded.source_url,end_basis=excluded.end_basis,source_section=excluded.source_section,updated_at=now()
   where course_private.terms.closed_at is null and(course_private.terms.closes_at is null or now()<course_private.terms.closes_at)and(excluded.verified or not course_private.terms.verified);
  if found then n:=n+1;end if;
 end loop;return n;
end $$;

create function course_private.term_open(p_term text,p_at timestamptz default now())returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from course_private.terms where term=p_term and verified and closed_at is null and p_at>=opens_at and p_at<closes_at)
$$;
create function public.course_terms(p_hash text)returns jsonb language plpgsql security invoker set search_path='' as $$
declare me uuid;begin
 me:=social_private.require_member(p_hash);
 return jsonb_build_object('schemaVersion',1,'timeZone','America/Chicago','serverNow',to_char(now()at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),'verifiedAt',coalesce((select to_char(max(updated_at)at time zone 'UTC','YYYY-MM-DD')from course_private.terms where verified),''),'terms',coalesce((select jsonb_agg(jsonb_build_object('id',term,'season',season,'year',year,'opensAt',opens_at,'endsOn',ends_on,'closesAt',closes_at,'purgeAt',purge_at,'sourceURL',source_url,'endBasis',end_basis,'sourceSection',source_section,'verified',verified)order by opens_at)from course_private.terms where year>=extract(year from now()at time zone 'America/Chicago')::int-1),'[]'));
exception when raise_exception then return jsonb_build_object('error',split_part(sqlerrm,':',2),'code',split_part(sqlerrm,':',1));
end $$;

-- Access checks are time-based, so the exact closing boundary does not wait for a worker.
do $$declare f text;begin
 foreach f in array array['social_private.can_read_room(uuid,text)','social_private.can_message(uuid,text)']loop
  execute replace(pg_get_functiondef(f::regprocedure),'where r.id=p_room and','where r.id=p_room and (r.kind<>''course'' or course_private.term_open(r.meta->>''term'')) and');
 end loop;
 f:=pg_get_functiondef('social_private.message_list(uuid,text)'::regprocedure);
 if position('where m.room=p_room and' in f)=0 then raise exception 'Message access patch missing';end if;
 execute replace(f,'where m.room=p_room and','where m.room=p_room and social_private.can_read_room(p_me,p_room) and');
 f:=pg_get_functiondef('course_private.canonical_course()'::regprocedure);
 if position('new.id:=item.code' in f)=0 then raise exception 'Course creation patch missing';end if;
 execute replace(f,'new.id:=item.code','if not course_private.term_open(semester) then raise exception ''closed:This semester is locked or has ended.'';end if;'||chr(10)||' new.id:=item.code');
 f:=pg_get_functiondef('course_private.membership_limit()'::regprocedure);
 execute replace(f,'if semester is null then return new;end if;','if semester is null then return new;end if; if not course_private.term_open(semester) then raise exception ''closed:This semester is locked or has ended.'';end if;');
 f:=pg_get_functiondef('social_private.snapshot(uuid)'::regprocedure);
 execute replace(f,'where r.kind=''course'' and rm.member=p_me','where r.kind=''course'' and course_private.term_open(r.meta->>''term'') and rm.member=p_me');
 f:=pg_get_functiondef('social_private.snapshot(uuid)'::regprocedure);
 execute replace(f,'where rm.member=p_me and rm.status in(''accepted'',''invited'')','where (r.kind<>''course'' or course_private.term_open(r.meta->>''term'')) and rm.member=p_me and rm.status in(''accepted'',''invited'')');
 f:=pg_get_functiondef('public.account_controls(text,text,jsonb)'::regprocedure);
 execute replace(replace(f,'where m.author=me order by m.created_at,m.id','where m.author=me and (r.kind<>''course'' or course_private.term_open(r.meta->>''term'')) order by m.created_at,m.id'),'where rm.member=me order by rm.joined_at,r.id','where rm.member=me and (r.kind<>''course'' or course_private.term_open(r.meta->>''term'')) order by rm.joined_at,r.id');
 f:=pg_get_functiondef('public.account_controls(text,text,jsonb)'::regprocedure);
 execute replace(f,'where owner=me order by created_at,id','where owner=me and (room is null or not exists(select 1 from social_private.rooms cr where cr.id=room and cr.kind=''course'' and not course_private.term_open(cr.meta->>''term''))) order by created_at,id');
 f:=pg_get_functiondef('public.course_activity(text,text)'::regprocedure);
 execute replace(f,'and r.meta->>''term''=p_term','and r.meta->>''term''=p_term and course_private.term_open(p_term)');
end $$;

create function public.course_lifecycle_maintenance(p_limit int default 100)returns jsonb language plpgsql security invoker set search_path='' as $$
declare entry record;n int:=0;closed_n int;begin
 update course_private.terms set closed_at=now()where verified and closes_at<=now()and closed_at is null;
 update social_private.rooms r set status='closed'from course_private.terms t where r.kind='course'and r.meta->>'term'=t.term and t.closed_at is not null and r.status<>'closed';
 get diagnostics closed_n=row_count;
 for entry in select r.id from social_private.rooms r join course_private.terms t on t.term=r.meta->>'term'where r.kind='course'and t.verified and t.closed_at is not null and t.purge_at<=now()order by t.purge_at,r.id limit greatest(1,least(p_limit,500))for update of r skip locked loop
  insert into social_private.storage_deletions(path)select path from social_private.attachments where room=entry.id and path is not null on conflict(path)do nothing;
  update social_private.reports set evidence=jsonb_build_object('redacted',true,'reason','Course retention expired')where evidence->>'room'=entry.id;
  delete from social_private.rooms where id=entry.id;
  n:=n+1;
 end loop;
 return jsonb_build_object('closed',closed_n,'purged',n);
end $$;
-- The existing hourly campus worker removes queued Storage objects through the Storage API.
create function public.course_media_cleanup_batch(p_limit int default 100)returns text[]language sql security invoker set search_path=''as $$select coalesce(array_agg(path),'{}')from(select path from social_private.storage_deletions order by created_at limit greatest(1,least(p_limit,500)))q$$;

revoke all on function public.claim_course_calendar_refresh(),public.course_calendar_ingest(jsonb),course_private.term_open(text,timestamptz),public.course_terms(text),public.course_lifecycle_maintenance(int),public.course_media_cleanup_batch(int)from public,anon,authenticated;
grant execute on function public.claim_course_calendar_refresh(),public.course_calendar_ingest(jsonb),course_private.term_open(text,timestamptz),public.course_terms(text),public.course_lifecycle_maintenance(int),public.course_media_cleanup_batch(int)to service_role;

-- Verified official dates and explicitly locked unpublished terms.
select public.course_calendar_ingest('[{"id":"Spring 2026","season":"Spring","year":2026,"opensAt":"2025-12-01T00:00:00-06:00","closesAt":"2026-05-06T00:00:00-05:00","purgeAt":"2026-06-06T00:00:00-05:00","endsOn":"2026-05-05","sourceURL":"https://catalog.tamu.edu/archives/2025-2026/undergraduate/academic-calendar/","sourceSection":"2026 Spring Semester","endBasis":"last_final_exam","verified":true},{"id":"Summer 2026","season":"Summer","year":2026,"opensAt":"2026-05-01T00:00:00-05:00","closesAt":"2026-08-07T00:00:00-05:00","purgeAt":"2026-09-07T00:00:00-05:00","endsOn":"2026-08-06","sourceURL":"https://catalog.tamu.edu/undergraduate/academic-calendar/","sourceSection":"2026 10-Week Summer Semester","endBasis":"last_final_exam","verified":true},{"id":"Fall 2026","season":"Fall","year":2026,"opensAt":"2026-08-01T00:00:00-05:00","closesAt":"2026-12-11T00:00:00-06:00","purgeAt":"2027-01-11T00:00:00-06:00","endsOn":"2026-12-10","sourceURL":"https://catalog.tamu.edu/undergraduate/academic-calendar/","sourceSection":"2026 Fall Semester","endBasis":"last_final_exam","verified":true},{"id":"Spring 2027","season":"Spring","year":2027,"opensAt":"2026-12-01T00:00:00-06:00","closesAt":"2027-05-12T00:00:00-05:00","purgeAt":"2027-06-12T00:00:00-05:00","endsOn":"2027-05-11","sourceURL":"https://catalog.tamu.edu/undergraduate/academic-calendar/","sourceSection":"2027 Spring Semester","endBasis":"last_final_exam","verified":true},{"id":"Summer 2027","season":"Summer","year":2027,"opensAt":"2027-05-01T00:00:00-05:00","closesAt":"2027-08-12T00:00:00-05:00","purgeAt":"2027-09-12T00:00:00-05:00","endsOn":"2027-08-11","sourceURL":"https://catalog.tamu.edu/undergraduate/academic-calendar/","sourceSection":"2027 10-Week Summer Semester","endBasis":"last_final_exam","verified":true},{"id":"Fall 2027","season":"Fall","year":2027,"opensAt":"2027-08-01T00:00:00-05:00","closesAt":null,"purgeAt":null,"endsOn":null,"sourceURL":"https://catalog.tamu.edu/undergraduate/academic-calendar/","sourceSection":"2027 Fall Semester","endBasis":"unpublished","verified":false},{"id":"Spring 2028","season":"Spring","year":2028,"opensAt":"2027-12-01T00:00:00-06:00","closesAt":null,"purgeAt":null,"endsOn":null,"sourceURL":"https://catalog.tamu.edu/undergraduate/academic-calendar/","sourceSection":"2028 Spring Semester","endBasis":"unpublished","verified":false},{"id":"Summer 2028","season":"Summer","year":2028,"opensAt":"2028-05-01T00:00:00-05:00","closesAt":null,"purgeAt":null,"endsOn":null,"sourceURL":"https://catalog.tamu.edu/undergraduate/academic-calendar/","sourceSection":"2028 10-Week Summer Semester","endBasis":"unpublished","verified":false},{"id":"Fall 2028","season":"Fall","year":2028,"opensAt":"2028-08-01T00:00:00-05:00","closesAt":null,"purgeAt":null,"endsOn":null,"sourceURL":"https://catalog.tamu.edu/undergraduate/academic-calendar/","sourceSection":"2028 Fall Semester","endBasis":"unpublished","verified":false}]'::jsonb);
