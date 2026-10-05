-- Shared memes: creations members chose to publish for everyone. KLIPY has no
-- upload API, so these live in our private bucket. Owners are never exposed.
create table social_private.shared_memes(
 id uuid primary key default gen_random_uuid(),
 owner uuid not null references social_private.members(id) on delete cascade,
 path text not null unique check(path ~ '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\.(jpg|png)$'),
 mime text not null check(mime in('image/jpeg','image/png')),
 size integer not null check(size>0 and size<=5000000),
 width integer not null check(width between 1 and 8192),
 height integer not null check(height between 1 and 8192),
 title text not null default '' check(char_length(title)<=80),
 created_at timestamptz not null default now(),
 removed_at timestamptz,
 report_count integer not null default 0,
 check(width*height<=12000000)
);
create index social_shared_memes_recent on social_private.shared_memes(created_at desc) where removed_at is null;
create index social_shared_memes_owner on social_private.shared_memes(owner,created_at);
create index social_shared_memes_title on social_private.shared_memes(lower(title)) where removed_at is null;
create table social_private.shared_meme_reports(
 meme uuid not null references social_private.shared_memes(id) on delete cascade,
 reporter uuid not null references social_private.members(id) on delete cascade,
 reason text not null default '' check(char_length(reason)<=200),
 created_at timestamptz not null default now(),
 primary key(meme,reporter)
);
alter table social_private.shared_memes enable row level security;
alter table social_private.shared_meme_reports enable row level security;
create policy "Server access" on social_private.shared_memes for all to service_role using(true) with check(true);
create policy "Server access" on social_private.shared_meme_reports for all to service_role using(true) with check(true);
revoke all on social_private.shared_memes,social_private.shared_meme_reports from public,anon,authenticated;
grant all on social_private.shared_memes,social_private.shared_meme_reports to service_role;
-- Cascading account deletion must still release the stored picture; the
-- hourly worker drains storage_deletions (root-level <uuid>.<ext> paths only).
create or replace function social_private.shared_meme_release() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if old.removed_at is null then insert into social_private.storage_deletions(path) values(old.path) on conflict do nothing;end if;
 return old;
end $$;
revoke all on function social_private.shared_meme_release() from public,anon,authenticated;
grant execute on function social_private.shared_meme_release() to service_role;
create trigger shared_meme_release before delete on social_private.shared_memes for each row execute function social_private.shared_meme_release();

create or replace function public.social_memes(p_action text,p_hash text,p_input jsonb default '{}') returns jsonb
language plpgsql security invoker set search_path='' as $$
declare me uuid; m social_private.shared_memes; page_number integer; query_text text; pattern text; rows jsonb; total integer; reporters integer; removed boolean:=false;
begin
 me:=social_private.require_member(p_hash);
 if p_action='publish' then
  if coalesce(p_input->>'mime','') not in('image/jpeg','image/png') then raise exception 'invalid:Share a still image as a meme.';end if;
  if (select count(*) from social_private.shared_memes where owner=me and created_at>now()-interval '24 hours')>=30 then raise exception 'rate_limit:You have shared a lot of memes today. Try again tomorrow.';end if;
  insert into social_private.shared_memes(owner,path,mime,size,width,height,title)
   values(me,p_input->>'path',p_input->>'mime',(p_input->>'size')::integer,(p_input->>'width')::integer,(p_input->>'height')::integer,
    left(regexp_replace(coalesce(p_input->>'title',''),'[[:cntrl:]]','','g'),80))
   returning * into m;
  return jsonb_build_object('meme_id',m.id,'meme',jsonb_build_object('id',m.id,'title',m.title,'mime',m.mime,'width',m.width,'height',m.height,'created_at',m.created_at));
 elsif p_action='list' then
  page_number:=greatest(1,coalesce((p_input->>'page')::integer,1));
  query_text:=left(trim(coalesce(p_input->>'query','')),60);
  pattern:='%'||replace(replace(replace(query_text,'\','\\'),'%','\%'),'_','\_')||'%';
  select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'title',s.title,'mime',s.mime,'width',s.width,'height',s.height,'created_at',s.created_at) order by s.created_at desc),'[]'),count(*)
   into rows,total
   from (select * from social_private.shared_memes sm where sm.removed_at is null
          and not exists(select 1 from social_private.members b where b.id=sm.owner and b.banned)
          and not social_private.blocked(me,sm.owner)
          and (query_text='' or sm.title ilike pattern escape '\')
         order by sm.created_at desc limit 25 offset (page_number-1)*24) s;
  if total>24 then rows:=(select jsonb_agg(value) from (select value from jsonb_array_elements(rows) with ordinality o(value,n) where n<=24 order by n) t);end if;
  return jsonb_build_object('memes',coalesce(rows,'[]'::jsonb),'has_next',total>24);
 elsif p_action='read' then
  select * into m from social_private.shared_memes where id=(p_input->>'meme_id')::uuid;
  if m.id is null or m.removed_at is not null or social_private.blocked(me,m.owner) then raise exception 'not_found:This meme is no longer available.';end if;
  return jsonb_build_object('meme_id',m.id,'path',m.path,'mime',m.mime);
 elsif p_action='report' then
  select * into m from social_private.shared_memes where id=(p_input->>'meme_id')::uuid for update;
  if m.id is null or m.removed_at is not null then raise exception 'not_found:This meme is no longer available.';end if;
  if m.owner=me then raise exception 'invalid:Remove your own meme instead of reporting it.';end if;
  insert into social_private.shared_meme_reports(meme,reporter,reason) values(m.id,me,left(regexp_replace(coalesce(p_input->>'reason',''),'[[:cntrl:]]','','g'),200))
   on conflict(meme,reporter) do update set reason=excluded.reason,created_at=now();
  select count(*) into reporters from social_private.shared_meme_reports where meme=m.id;
  update social_private.shared_memes set report_count=reporters where id=m.id;
  if reporters>=3 then
   update social_private.shared_memes set removed_at=now() where id=m.id and removed_at is null;
   insert into social_private.storage_deletions(path) values(m.path) on conflict do nothing;
   removed:=true;
  end if;
  insert into social_private.reports(reporter,target_type,target_id,reason,evidence) values(me,'shared_meme',m.id::text,left(coalesce(p_input->>'reason','Shared meme report'),200),jsonb_build_object('title',m.title,'reports',reporters));
  return jsonb_build_object('ok',true,'removed',removed);
 elsif p_action='remove' then
  select * into m from social_private.shared_memes where id=(p_input->>'meme_id')::uuid for update;
  if m.id is null then raise exception 'not_found:This meme is no longer available.';end if;
  if m.owner<>me then raise exception 'forbidden:Only the person who shared this meme can remove it.';end if;
  if m.removed_at is null then
   update social_private.shared_memes set removed_at=now() where id=m.id;
   insert into social_private.storage_deletions(path) values(m.path) on conflict do nothing;
  end if;
  return jsonb_build_object('ok',true,'path',m.path);
 else raise exception 'invalid:Unknown meme action.';end if;
exception when others then
 if position(':' in sqlerrm)>0 and split_part(sqlerrm,':',1) in('unauthorized','forbidden','invalid','rate_limit','not_found') then return jsonb_build_object('code',split_part(sqlerrm,':',1),'error',substring(sqlerrm from position(':' in sqlerrm)+1));end if;
 return jsonb_build_object('code','invalid','error','The meme library could not complete that request.');
end $$;
comment on function public.social_memes(text,text,jsonb) is 'Shared meme library: publish/list/read/report/remove. Service-role only; never returns who shared a meme.';
revoke all on function public.social_memes(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.social_memes(text,text,jsonb) to service_role;
