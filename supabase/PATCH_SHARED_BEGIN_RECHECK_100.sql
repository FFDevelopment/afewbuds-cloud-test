create or replace function afb_play_private.begin_play(p_session_token text,p_play_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a uuid:=public.afb_account_from_token(p_session_token); h text;
 l afb_play_private.leases%rowtype; s jsonb;
begin
 if a is null then raise exception 'session_invalid'; end if;
 if p_play_id is null then raise exception 'play_id_required'; end if;
 h:=encode(extensions.digest(p_session_token,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended(a::text,81731));
 if public.afb_account_from_token(p_session_token) is distinct from a then raise exception 'session_invalid'; end if;
 insert into afb_play_private.original_careers(account_id,save_json)
 select account_id,save_json from public.afb_player_saves where account_id=a on conflict do nothing;
 insert into afb_play_private.leases(account_id) values(a) on conflict do nothing;
 select * into l from afb_play_private.leases where account_id=a for update;
 if l.play_id is distinct from p_play_id then
  if l.pending_id is not null and l.pending_id<>p_play_id and l.pending_since>clock_timestamp()-interval '30 seconds' then
   return jsonb_build_object('state','waiting','reason','another_switch_in_progress');
  end if;
  if l.play_id is not null and l.heartbeat>clock_timestamp()-interval '20 seconds' then
   if l.pending_id is distinct from p_play_id then
    update afb_play_private.leases set pending_id=p_play_id,pending_hash=h,pending_since=clock_timestamp() where account_id=a;
    return jsonb_build_object('state','waiting');
   end if;
   if l.pending_since>clock_timestamp()-interval '15 seconds' then return jsonb_build_object('state','waiting'); end if;
  end if;
  update afb_play_private.leases set play_id=p_play_id,token_hash=h,heartbeat=clock_timestamp(),pending_id=null,pending_hash=null,pending_since=null where account_id=a;
  -- A new device invalidates other login tokens; same-token browser tabs are fenced by play_id.
  delete from public.afb_login_sessions where account_id=a and token_hash<>h;
 elsif l.token_hash is distinct from h then
  raise exception 'session_replaced';
 end if;
 select save_json into s from public.afb_player_saves where account_id=a;
 return jsonb_build_object('state','active','revision',l.revision,'exists',s is not null,'save_json',coalesce(s,'{}'::jsonb));
end; $$;