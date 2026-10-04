create schema if not exists social_private;
revoke all on schema social_private from public,anon,authenticated;
grant usage on schema social_private to service_role;
create table social_private.members (
 id uuid primary key default gen_random_uuid(), token_hash text unique not null check(token_hash ~ '^[a-f0-9]{64}$'),
 username text unique not null check(username ~ '^[a-z0-9_]{3,20}$'), adult boolean not null default false,
 nsfw_enabled boolean not null default false, banned boolean not null default false,
 network_hash text not null, created_at timestamptz not null default now(), seen_at timestamptz not null default now(),
 rate_window timestamptz not null default now(), rate_count integer not null default 0
);
create index social_members_network on social_private.members(network_hash,created_at);
create table social_private.blocks(blocker uuid references social_private.members on delete cascade,blocked uuid references social_private.members on delete cascade,primary key(blocker,blocked),check(blocker<>blocked));
create index social_blocks_reverse on social_private.blocks(blocked);
create table social_private.posts(id uuid primary key default gen_random_uuid(),author uuid references social_private.members on delete set null,nonce uuid not null,body text not null,anonymous boolean not null default true,community text not null default 'Texas A&M' check(community in ('Texas A&M','NSFW')),accepts_dm boolean not null default false,deleted boolean not null default false,created_at timestamptz not null default now(),unique(author,nonce));
create table social_private.comments(id uuid primary key default gen_random_uuid(),post uuid not null references social_private.posts on delete cascade,author uuid references social_private.members on delete set null,nonce uuid not null,body text not null,anonymous boolean not null default true,deleted boolean not null default false,created_at timestamptz not null default now(),unique(author,nonce));
create index social_comments_post on social_private.comments(post,created_at);
create table social_private.votes(member uuid references social_private.members on delete cascade,post uuid references social_private.posts on delete cascade,value integer not null check(value in(-1,1)),primary key(member,post));
create index social_votes_post on social_private.votes(post);
create table social_private.bookmarks(member uuid references social_private.members on delete cascade,post uuid references social_private.posts on delete cascade,primary key(member,post));
create index social_bookmarks_post on social_private.bookmarks(post);
create table social_private.rooms(id text primary key default gen_random_uuid()::text,kind text not null check(kind in('course','dm','activity','group','sports','organization')),title text not null,status text not null default 'active' check(status in('active','pending','closed')),anonymous boolean not null default false,requester uuid references social_private.members on delete set null,context_post uuid references social_private.posts on delete set null,meta jsonb not null default '{}',created_at timestamptz not null default now());
create table social_private.room_members(room text references social_private.rooms on delete cascade,member uuid references social_private.members on delete cascade,role text not null default 'member',status text not null default 'accepted' check(status in('accepted','invited','declined','waitlisted','pending')),last_read bigint not null default 0,typing_until timestamptz,joined_at timestamptz not null default now(),primary key(room,member));
create index social_room_members_member on social_private.room_members(member);
create table social_private.messages(id uuid primary key default gen_random_uuid(),seq bigint generated always as identity unique,room text not null references social_private.rooms on delete cascade,author uuid references social_private.members on delete set null,nonce uuid not null,body text not null default '',reply_to uuid references social_private.messages on delete set null,game text,game_session_id uuid,deleted boolean not null default false,created_at timestamptz not null default now(),unique(author,nonce));
create index social_messages_room on social_private.messages(room,seq);
create index social_messages_reply on social_private.messages(reply_to);
create table social_private.reactions(message uuid references social_private.messages on delete cascade,member uuid references social_private.members on delete cascade,emoji text not null,primary key(message,member,emoji));
create index social_reactions_member on social_private.reactions(member);
create table social_private.activities(id uuid primary key default gen_random_uuid(),room text unique not null references social_private.rooms on delete cascade,host uuid references social_private.members on delete set null,title text not null,kind text not null,place text not null,starts timestamptz not null,capacity integer not null check(capacity between 2 and 100),details text not null default '',course text,cancelled boolean not null default false,approval_required boolean not null default false,created_at timestamptz not null default now());
create table social_private.attachments(id uuid primary key default gen_random_uuid(),owner uuid references social_private.members on delete cascade,room text references social_private.rooms on delete cascade,post uuid references social_private.posts on delete cascade,message uuid unique references social_private.messages on delete cascade,kind text not null check(kind in('image','gif')),mime text not null,size integer not null check(size between 1 and 5000000),path text unique not null,ready boolean not null default false,created_at timestamptz not null default now(),check(room is not null or post is not null));
create index social_attachments_room on social_private.attachments(room);
create index social_attachments_post on social_private.attachments(post);
create index social_attachments_owner on social_private.attachments(owner);
create table social_private.reports(id uuid primary key default gen_random_uuid(),reporter uuid references social_private.members on delete set null,target_type text not null,target_id text not null,reason text not null,evidence jsonb not null default '{}',status text not null default 'pending',created_at timestamptz not null default now());
create table social_private.hidden(member uuid references social_private.members on delete cascade,post uuid references social_private.posts on delete cascade,primary key(member,post));
create index social_hidden_post on social_private.hidden(post);
create table social_private.saved_events(member uuid references social_private.members on delete cascade,event_id text not null,primary key(member,event_id));
create table social_private.organizations(id uuid primary key default gen_random_uuid(),name text unique not null,about text not null default '',status text not null default 'pending' check(status in('pending','verified','suspended','declined')),application jsonb not null default '{}',created_at timestamptz not null default now());
create table social_private.organization_admins(organization uuid references social_private.organizations on delete cascade,member uuid references social_private.members on delete cascade,role text not null default 'admin',primary key(organization,member));
create index social_org_admin_member on social_private.organization_admins(member);
create table social_private.organization_follows(organization uuid references social_private.organizations on delete cascade,member uuid references social_private.members on delete cascade,primary key(organization,member));
create index social_org_follow_member on social_private.organization_follows(member);
create table social_private.friends(a uuid references social_private.members on delete cascade,b uuid references social_private.members on delete cascade,status text not null default 'pending',primary key(a,b),check(a<>b));
create index social_friends_b on social_private.friends(b);
-- Private service-only schema: no public table grants, with RLS for defense in depth.
do $$ declare t text; begin for t in select tablename from pg_tables where schemaname='social_private' loop execute format('alter table social_private.%I enable row level security',t); execute format('create policy "Server access" on social_private.%I for all to service_role using(true) with check(true)',t); end loop; end $$;
revoke all on all tables in schema social_private from public,anon,authenticated;
grant all on all tables in schema social_private to service_role;
grant usage,select on all sequences in schema social_private to service_role;
create or replace function social_private.require_member(p_hash text) returns uuid language plpgsql security invoker set search_path='' as $$
declare m social_private.members; begin
 if p_hash is null or p_hash !~ '^[a-f0-9]{64}$' then raise exception 'unauthorized:Sign in to continue.'; end if;
 select * into m from social_private.members where token_hash=p_hash for update;
 if m.id is null then raise exception 'unauthorized:Your account credential is unavailable.'; end if;
 if m.banned then raise exception 'forbidden:This account is suspended.'; end if;
 if m.rate_window>now()-interval '1 minute' and m.rate_count>=600 then raise exception 'rate_limit:Please slow down and try again shortly.'; end if;
 update social_private.members set seen_at=now(),rate_window=case when rate_window<now()-interval '1 minute' then now() else rate_window end,rate_count=case when rate_window<now()-interval '1 minute' then 1 else rate_count+1 end where id=m.id;
 return m.id;
end $$;
create or replace function social_private.blocked(a uuid,b uuid) returns boolean language sql stable security invoker set search_path='' as $$ select exists(select 1 from social_private.blocks where (blocker=a and blocked=b) or (blocker=b and blocked=a)) $$;
create or replace function social_private.can_message(p_member uuid,p_room text) returns boolean language sql stable security invoker set search_path='' as $$
 select exists(select 1 from social_private.rooms r join social_private.room_members rm on rm.room=r.id where r.id=p_room and r.status='active' and rm.member=p_member and rm.status='accepted' and not exists(select 1 from social_private.room_members other where other.room=r.id and r.kind='dm' and social_private.blocked(p_member,other.member)))
$$;
revoke all on function social_private.require_member(text),social_private.blocked(uuid,uuid),social_private.can_message(uuid,text) from public,anon,authenticated;
grant execute on function social_private.require_member(text),social_private.blocked(uuid,uuid),social_private.can_message(uuid,text) to service_role;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('social-media','social-media',false,5000000,array['image/jpeg','image/png','image/gif']) on conflict(id) do nothing;
