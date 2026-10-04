-- Removing an unknown administrator key or revoking a non-pending invitation is an error, never a silent "changed".
do $patch$
declare def text; old text;
begin
 def:=pg_get_functiondef('public.organization_access(text,text,jsonb)'::regprocedure);
 old:='if target_id=me then raise exception ''invalid:Transfer ownership before leaving.'';end if;';
 if strpos(def,old)=0 then raise exception 'remove anchor missing';end if;
 def:=replace(def,old,'if target_id is null then raise exception ''invalid:This administrator is no longer listed.'';end if;'||old);
 old:='update organization_private.invitations set status=''revoked''where id=(p_input->>''invitation_id'')::uuid and organization=oid and status=''pending'';';
 if strpos(def,old)=0 then raise exception 'revoke anchor missing';end if;
 def:=replace(def,old,old||'if not found then raise exception ''invalid:This invitation is no longer pending.'';end if;');
 execute def;
end $patch$;
