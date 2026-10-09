-- Topic feeds, part 3: a pre-post text filter and a slower posting limit.
-- * social_private.text_filter_terms is a denylist the operator extends (filter.add / filter.remove,
--   audited). Terms are stored as the sha256 hex of the normalized word, so this public repository
--   carries no plain list. Text is normalized to lowercase and split into runs of letters and
--   digits; only whole words are compared, so a listed word inside a longer word never matches.
-- * The seed is a short, conservative list of unambiguous slurs (hashes only).
-- * rich_post_create rejects a new post whose text, poll or tags contain a listed word
--   ("invalid:This post includes language that isn't allowed here."); reply creation does the
--   same for replies. Nonce retries of a post or reply that already exists still return it.
-- * rich_post_create also allows at most 5 new posts per 15 minutes, on top of the existing
--   10-per-minute burst, with the same "rate_limit:Take a moment before posting again." copy.

create table if not exists social_private.text_filter_terms(
 hash text primary key check (hash ~ '^[0-9a-f]{64}$'),
 added_at timestamptz not null default now()
);
alter table social_private.text_filter_terms enable row level security;
revoke all on social_private.text_filter_terms from public,anon,authenticated;
grant select on social_private.text_filter_terms to service_role;

insert into social_private.text_filter_terms(hash)values
 ('044eb98b18769b887d5a0258f675e413058b8e9fc9b9786b418bfc6f03f26c98'),
 ('0ce875d620076b533c6e681abaa0dc5d9a941366bb000a02ec5351f341b96c61'),
 ('120f6e5b4ea32f65bda68452fcfaaef06b0136e1d0e4a6f60bc3771fa0936dd6'),
 ('12e6274e4309293e2d480272b49a6c7c73a6a6b22678ba226b533c67006c17d1'),
 ('16ea09fc78ca83ca502cbcf2377acdf280bf18f61e259153f0868405eedab5ef'),
 ('17a110e5332848721f27510e1e2bca710a321663bb8a5632e0e46a820fc9e28a'),
 ('1e02eec4f1095143be282056557034d4e8ab915342c1af508223141d472d2347'),
 ('22fc75e65a0e9d34324092a7c6a8dba961853294abca4e5914e60c550f48e0c2'),
 ('268651b3ece980102f18871fde07189372961e056f858ca147a28d004f876b03'),
 ('333f7618092958c75b8c5af6f1ec77b42803922a0fc6ff1570a8af3a3aab3b4a'),
 ('402f7ebd98864afed4817ff4718d357dbfa95458aa4236d6c5959536956fa4e5'),
 ('5b3ae48be122f7ed19b4cc587649f41f9d2565df51cfa332f8e7806f4ebb9032'),
 ('82159dd02870c13ec30e4f146db7c317aca568469d0e7e22b8610a2eaa3d3924'),
 ('8f5083e3e5c7dc8932f2bf58212f963f3a44752618c96297f82623f736c52738'),
 ('98b52c4b6b7d1f48e7477a5ccc10955dd195d0ac5a38c8281bfeb08762634909'),
 ('bb209d506bb8b17815af0e50923c3d8f65985dab91083f026f1881a7430c5cc7'),
 ('c3de533e9b7fe63b79f648687a30d2861edd92fe7c3cd1f2c485e0a605367624'),
 ('cc02032349c833ac5e97bac094560ed40e09acf34cb1978ab7a9840b9bf15b4d'),
 ('da0a6b1b9213d48ff10cc45733cc8a925dbd2afb26320ed488ac2efa9a8ae33a'),
 ('eef3bd091670c3447022d619c06ad15de96da72b5a66f28bb8b75d1b1c12a05f')
on conflict(hash)do nothing;

-- The distinct normalized words of a text: lowercase runs of letters and digits.
create or replace function social_private.text_filter_words(p_text text) returns text[] language sql immutable set search_path='' as $$
 select coalesce(array_agg(distinct w),'{}') from regexp_split_to_table(lower(coalesce(p_text,'')),'[^[:alnum:]]+') w where w<>''
$$;
-- Whether any whole word of the text is on the denylist.
create or replace function social_private.text_filter_hit(p_text text) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from unnest(social_private.text_filter_words(p_text)) w
  join social_private.text_filter_terms t on t.hash=encode(sha256(convert_to(w,'UTF8')),'hex'))
$$;

do $patch$
declare def text; old text; replacement text;
begin
 -- Posts: after the nonce lookup (an existing post is returned unchanged) and the burst limit.
 def:=pg_get_functiondef('social_private.rich_post_create(uuid,uuid,jsonb)'::regprocedure);
 old:='if(select count(*)from social_private.posts where author=p_me and created_at>now()-interval ''1 minute'')>=10 then raise exception ''rate_limit:Take a moment before posting again.'';end if;';
 replacement:=old||E'\n if(select count(*)from social_private.posts where author=p_me and created_at>now()-interval \'15 minutes\')>=5 then raise exception \'rate_limit:Take a moment before posting again.\';end if;'
  ||E'\n if social_private.text_filter_hit(concat_ws(\' \',body_value,question_value,array_to_string(options_value,\' \'),array_to_string(tags_value,\' \')))then raise exception \'invalid:This post includes language that isn\'\'t allowed here.\';end if;';
 if strpos(def,old)=0 then raise exception 'rich_post_create rate limit anchor missing';end if;
 execute replace(def,old,replacement);

 -- Replies: only a new reply is checked (a nonce retry returns the existing one).
 def:=pg_get_functiondef('public.social_gateway(text,text,jsonb)'::regprocedure);
 old:='if(select count(*)from social_private.comments where author=me and created_at>now()-interval ''1 minute'')>=30 then raise exception ''rate_limit:Take a moment before replying again.'';end if;';
 replacement:=old||E'\n    if social_private.text_filter_hit(body_value)then raise exception \'invalid:This reply includes language that isn\'\'t allowed here.\';end if;';
 if strpos(def,old)=0 then raise exception 'gateway reply rate limit anchor missing';end if;
 execute replace(def,old,replacement);

 -- Operator: filter.add / filter.remove take {"hash": sha256 hex of the normalized word}
 -- (tools/social-admin.py normalizes and hashes locally, so the word never reaches SQL or logs).
 def:=pg_get_functiondef('social_private.operator(text,jsonb,text)'::regprocedure);
 old:='result jsonb;topic_value text;';
 if strpos(def,old)=0 then raise exception 'operator declare anchor missing';end if;
 def:=replace(def,old,old||'term_hash text;');
 old:=' return social_private.operator_before_notifications(p_action,p_input,p_reviewer);';
 if strpos(def,old)=0 then raise exception 'operator delegate anchor missing';end if;
 replacement:=$r$ if p_action in('filter.add','filter.remove')then
  if char_length(btrim(p_reviewer))not between 3 and 100 or char_length(note_value)not between 5 and 2000 then raise exception 'Provide a reviewer label and review note.';end if;
  term_hash:=lower(btrim(coalesce(p_input->>'hash','')));
  if term_hash!~'^[0-9a-f]{64}$'then raise exception 'Give the sha256 hex of one normalized word';end if;
  if p_action='filter.add'then insert into social_private.text_filter_terms(hash)values(term_hash)on conflict(hash)do nothing;
  else delete from social_private.text_filter_terms where hash=term_hash;end if;
  insert into social_private.operator_audit(reviewer,action,target,reason)values(btrim(p_reviewer),p_action,term_hash,note_value);
  return jsonb_build_object('applied',true,'action',p_action,'hash',term_hash);
 end if;
$r$||old;
 execute replace(def,old,replacement);
end $patch$;
revoke all on function social_private.operator(text,jsonb,text) from public,anon,authenticated,service_role;

do $grants$
declare fn text;
begin
 foreach fn in array array['social_private.text_filter_words(text)','social_private.text_filter_hit(text)'] loop
  execute format('revoke all on function %s from public,anon,authenticated',fn);
  execute format('grant execute on function %s to service_role',fn);
 end loop;
end $grants$;
