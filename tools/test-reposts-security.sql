-- Repost (quote post) protocol and privacy assertions with synthetic fixtures; everything rolls back.
-- Run through psql as the database owner: the MCP SQL runner refuses scripts that write.
begin;
set local role service_role;
do $$
declare
 ha text:=encode(extensions.gen_random_bytes(32),'hex');hb text:=encode(extensions.gen_random_bytes(32),'hex');hc text:=encode(extensions.gen_random_bytes(32),'hex');
 a uuid;b uuid;c uuid;src uuid;anon_src uuid;quote_id uuid;second_quote uuid;chain uuid;nsfw_src uuid;own_quote uuid;reported uuid;relay uuid;nonce_id uuid:=gen_random_uuid();out jsonb;obj jsonb;snap jsonb;name_a text;name_c text;
begin
 if has_function_privilege('anon','social_private.quote_view(uuid,uuid)','EXECUTE')or has_function_privilege('authenticated','social_private.quote_view(uuid,uuid)','EXECUTE')or has_column_privilege('anon','social_private.posts','quoted_post','SELECT')or has_column_privilege('authenticated','social_private.posts','quoted_post','SELECT')then raise exception 'Private quote projection exposed';end if;
 name_a:='quote_a_'||substr(ha,1,8);name_c:='quote_c_'||substr(hc,1,8);
 insert into social_private.members(token_hash,username,adult,network_hash)values(ha,name_a,true,ha)returning id into a;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hb,'quote_b_'||substr(hb,1,8),true,hb)returning id into b;
 insert into social_private.members(token_hash,username,adult,network_hash)values(hc,name_c,true,hc)returning id into c;
 out:=public.social_gateway('post.create',ha,'{"text":"Named source for quoting","anonymous":false,"acceptsDM":false}');src:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('post.create',hc,'{"text":"Anonymous source for quoting","anonymous":true}');anon_src:=(out->>'resource_id')::uuid;
 -- A quote with an empty body is a complete post; the quote alone without any post is not.
 out:=public.social_gateway('post.create',hb,'{"text":""}');if out->>'code'is distinct from 'invalid'then raise exception 'Empty post without a quote accepted %',out;end if;
 out:=public.social_gateway('post.create',hb,jsonb_build_object('text','','anonymous',false,'nonce',nonce_id,'quoted_post_id',src));quote_id:=(out->>'resource_id')::uuid;
 if quote_id is null or not exists(select 1 from social_private.posts where id=quote_id and quoted_post=src and body='')then raise exception 'Quote creation failed %',out;end if;
 select v into obj from jsonb_array_elements(out->'snapshot'->'posts')v where v->>'id'=quote_id::text;
 if obj->'quote'->>'id'is distinct from src::text or obj->'quote'->>'unavailable'is distinct from 'false'or obj->'quote'->>'author'is distinct from name_a or obj->'quote'->>'anonymous'is distinct from 'false'or obj->'quote'->>'text'is distinct from 'Named source for quoting'or jsonb_typeof(obj->'quote'->'created')<>'number'or obj->'quote'?'vote'or obj->'quote'?'score'or obj->'quote'?'karma'or (obj->'quote')::text like '%'||a::text||'%'then raise exception 'Named quote projection wrong %',obj->'quote';end if;
 if(obj->>'repostCount')::int<>0 then raise exception 'Fresh quote post has reposts %',obj;end if;
 select v into obj from jsonb_array_elements(out->'snapshot'->'posts')v where v->>'id'=src::text;
 if(obj->>'repostCount')::int<>1 or obj->'quote'<>'null'::jsonb then raise exception 'Source repost count not projected %',obj;end if;
 -- Exact retry returns the same post; a changed quote on the same nonce is a conflict.
 out:=public.social_gateway('post.create',hb,jsonb_build_object('text','','anonymous',false,'nonce',nonce_id,'quoted_post_id',src));if out->>'resource_id'is distinct from quote_id::text then raise exception 'Quote retry not idempotent %',out;end if;
 out:=public.social_gateway('post.create',hb,jsonb_build_object('text','','anonymous',false,'nonce',nonce_id,'quoted_post_id',anon_src));if out->>'code'is distinct from 'conflict'then raise exception 'Changed quote retry accepted %',out;end if;
 out:=public.social_gateway('post.create',hb,jsonb_build_object('text','','anonymous',false,'nonce',nonce_id));if out->>'code'is distinct from 'conflict'then raise exception 'Dropped quote retry accepted %',out;end if;
 -- Unknown, malformed and non-string quote targets are rejected before anything is written.
 out:=public.social_gateway('post.create',hb,jsonb_build_object('text','ghost','quoted_post_id',gen_random_uuid()));if out->>'code'is distinct from 'invalid'then raise exception 'Nonexistent quote accepted %',out;end if;
 out:=public.social_gateway('post.create',hb,'{"text":"ghost","quoted_post_id":"not-a-uuid"}');if out->>'code'is distinct from 'invalid'then raise exception 'Malformed quote id accepted %',out;end if;
 out:=public.social_gateway('post.create',hb,'{"text":"ghost","quoted_post_id":7}');if out->>'code'is distinct from 'invalid'then raise exception 'Numeric quote id accepted %',out;end if;
 out:=public.social_gateway('post.create',hb,'{"text":"explicit null quote","quoted_post_id":null}');if out->>'resource_id'is null or exists(select 1 from social_private.posts where id=(out->>'resource_id')::uuid and quoted_post is not null)then raise exception 'Null quote mishandled %',out;end if;
 -- An anonymous source stays anonymous in everyone else's quote card; its own author sees the username.
 out:=public.social_gateway('post.create',hb,jsonb_build_object('text','Quoting an anonymous post','quoted_post_id',anon_src));second_quote:=(out->>'resource_id')::uuid;
 snap:=social_private.snapshot(a);select v into obj from jsonb_array_elements(snap->'posts')v where v->>'id'=second_quote::text;
 if obj->'quote'->>'author'is distinct from 'Anonymous'or obj->'quote'->>'anonymous'is distinct from 'true'or obj::text like '%'||c::text||'%'or obj::text like '%'||name_c||'%'then raise exception 'Anonymous source identity leaked through a quote %',obj;end if;
 snap:=social_private.snapshot(c);select v into obj from jsonb_array_elements(snap->'posts')v where v->>'id'=second_quote::text;
 if obj->'quote'->>'author'is distinct from name_c then raise exception 'Author does not see own quoted post by name %',obj->'quote';end if;
 -- Owners may quote themselves; a quote of a quote projects one level only.
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Quoting myself','quoted_post_id',src));own_quote:=(out->>'resource_id')::uuid;if own_quote is null then raise exception 'Self quote refused %',out;end if;
 out:=public.social_gateway('post.create',hc,jsonb_build_object('text','Quote of a quote','quoted_post_id',quote_id));chain:=(out->>'resource_id')::uuid;if chain is null then raise exception 'Quote of a quote refused %',out;end if;
 select v into obj from jsonb_array_elements(out->'snapshot'->'posts')v where v->>'id'=chain::text;
 if obj->'quote'->>'id'is distinct from quote_id::text or obj->'quote'?'quote'or obj->'quote'?'repostCount'then raise exception 'Nested quote projected beyond one level %',obj->'quote';end if;
 select v into obj from jsonb_array_elements(out->'snapshot'->'posts')v where v->>'id'=src::text;
 if(obj->>'repostCount')::int<>2 then raise exception 'Repost count should count both live quotes %',obj;end if;
 -- Export of the member's own posts carries the quoted post id.
 out:=public.account_controls('export',hb,'{"section":"posts"}');if not exists(select 1 from jsonb_array_elements(out->'data')v where v->>'id'=quote_id::text and v->>'quoted_post'=src::text)then raise exception 'Own export lacks quoted_post %',out;end if;
 -- Deleting the source keeps the quoting post, hides the quoted body and stops counting its quotes; a deleted post cannot be quoted again.
 out:=public.social_gateway('post.delete',ha,jsonb_build_object('post_id',src));if out?'error'then raise exception 'Source deletion failed %',out;end if;
 snap:=social_private.snapshot(b);select v into obj from jsonb_array_elements(snap->'posts')v where v->>'id'=quote_id::text;
 if obj->>'deleted'is distinct from 'false'or obj->'quote'->>'unavailable'is distinct from 'true'or obj->'quote'?'text'or obj->'quote'?'author'or obj->'quote'->>'id'is distinct from src::text then raise exception 'Deleted source not projected as unavailable %',obj->'quote';end if;
 select v into obj from jsonb_array_elements(snap->'posts')v where v->>'id'=src::text;
 if obj->'quote'<>'null'::jsonb then raise exception 'Deleted post still carries a quote %',obj;end if;
 out:=public.social_gateway('post.create',hb,jsonb_build_object('text','Late quote','quoted_post_id',src));if out->>'code'is distinct from 'invalid'then raise exception 'Deleted source accepted a new quote %',out;end if;
 -- A block in either direction collapses existing quotes and refuses new ones.
 insert into social_private.blocks(blocker,blocked)values(c,b);
 snap:=social_private.snapshot(b);select v into obj from jsonb_array_elements(snap->'posts')v where v->>'id'=second_quote::text;
 if obj->'quote'->>'unavailable'is distinct from 'true'or obj->'quote'?'text'then raise exception 'Blocked source still quoted %',obj->'quote';end if;
 out:=public.social_gateway('post.create',hb,jsonb_build_object('text','Blocked quote','quoted_post_id',anon_src));if out->>'code'is distinct from 'invalid'then raise exception 'Blocked pair accepted a quote %',out;end if;
 delete from social_private.blocks where blocker=c and blocked=b;
 snap:=social_private.snapshot(b);select v into obj from jsonb_array_elements(snap->'posts')v where v->>'id'=second_quote::text;
 if obj->'quote'->>'unavailable'is distinct from 'false'then raise exception 'Quote did not recover after unblock %',obj->'quote';end if;
 -- Deleting the quoting post leaves the source untouched and stops counting it.
 out:=public.social_gateway('post.delete',hb,jsonb_build_object('post_id',second_quote));
 snap:=social_private.snapshot(c);select v into obj from jsonb_array_elements(snap->'posts')v where v->>'id'=anon_src::text;
 if obj->>'deleted'is distinct from 'false'or(obj->>'repostCount')::int<>0 then raise exception 'Deleted quote still counted %',obj;end if;
 -- Adult discussions stay in the adult community: an NSFW post may be quoted only into NSFW, and only by members who can read it.
 update social_private.members set nsfw_enabled=true where id in(b,c);
 out:=public.social_gateway('post.create',hc,'{"text":"Adult source","community":"NSFW"}');nsfw_src:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('post.create',hb,jsonb_build_object('text','Leaking adult content','community','Texas A&M','quoted_post_id',nsfw_src));if out->>'code'is distinct from 'invalid'or out->>'error'is distinct from 'Keep adult discussions in the adult community.'then raise exception 'NSFW quote into main feed accepted %',out;end if;
 out:=public.social_gateway('post.create',hb,jsonb_build_object('text','Adult quote stays adult','community','NSFW','quoted_post_id',nsfw_src));if out->>'resource_id'is null then raise exception 'NSFW quote into NSFW refused %',out;end if;
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','Outsider quote','community','Texas A&M','quoted_post_id',nsfw_src));if out->>'code'is distinct from 'invalid'then raise exception 'Non-member quoted an adult post %',out;end if;
 snap:=social_private.snapshot(a);if exists(select 1 from jsonb_array_elements(snap->'posts')v where v->'quote'->>'id'=nsfw_src::text and v->'quote'->>'unavailable'='false')then raise exception 'Adult quote body shown to a non-member';end if;
 -- Suspending the source author hides the quoted body; account deletion leaves an unavailable card, never an orphaned reference error.
 update social_private.members set banned=true where id=c;
 snap:=social_private.snapshot(b);select v into obj from jsonb_array_elements(snap->'posts')v where v->'quote'->>'id'=nsfw_src::text;
 if obj->'quote'->>'unavailable'is distinct from 'true'then raise exception 'Suspended author still quoted %',obj->'quote';end if;
 update social_private.members set banned=false where id=c;
 -- A source the viewer reported is hidden for that viewer, inside quote cards too; report evidence keeps the quoted text.
 out:=public.social_gateway('post.create',ha,'{"text":"Source b will report"}');reported:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('post.create',ha,jsonb_build_object('text','','quoted_post_id',reported));relay:=(out->>'resource_id')::uuid;
 out:=public.social_gateway('report',hb,jsonb_build_object('target_type','post','target_id',reported,'reason','Quote visibility QA'));
 if social_private.quote_view(b,reported)<>jsonb_build_object('id',reported,'unavailable',true)then raise exception 'Reported source still visible in quote card %',social_private.quote_view(b,reported);end if;
 if (social_private.quote_view(a,reported)->>'unavailable')::boolean then raise exception 'Report hid the source from its own author';end if;
 out:=public.social_gateway('report',hb,jsonb_build_object('target_type','post','target_id',relay,'reason','Quote evidence QA'));
 if not exists(select 1 from social_private.reports where reporter=b and target_id=relay::text and evidence->>'quotedPost'=reported::text and evidence->>'quotedText'='Source b will report')then raise exception 'Quote report evidence missing the quoted post';end if;
 if (social_private.quote_view(a,relay)->>'quotes')::boolean is distinct from true then raise exception 'Quote-of-quote flag missing';end if;
 out:=public.social_gateway('account.delete',hc);if out?'error'then raise exception 'Source author deletion failed %',out;end if;
 snap:=social_private.snapshot(b);select v into obj from jsonb_array_elements(snap->'posts')v where v->'quote'->>'id'=nsfw_src::text;
 if obj->'quote'->>'unavailable'is distinct from 'true'or obj::text like '%'||name_c||'%'then raise exception 'Deleted account quote leaked %',obj;end if;
end $$;
select 'PASS quote creation with empty body, named/anonymous/own projection without identity leaks, one-level nesting, repost counts, nonce retry and conflict, unknown/malformed targets, deleted/blocked/suspended/deleted-account/reported sources collapse to unavailable, quote report evidence, quote-of-quote flag, NSFW containment and own export' result;
rollback;
