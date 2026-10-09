-- One active game per account. Existing login RPCs remain unchanged.
-- Custom AFewBuds session tokens (not Supabase Auth JWTs) prove account ownership.
create schema if not exists afb_play_private;
revoke all on schema afb_play_private from public;
grant usage on schema afb_play_private to anon, authenticated;
create table afb_play_private.leases (
 account_id uuid primary key references public.afb_player_accounts(id) on delete cascade,
 play_id uuid, token_hash text, heartbeat timestamptz,
 pending_id uuid, pending_hash text, pending_since timestamptz,
 revision bigint not null default 0
);
create table afb_play_private.original_careers (
 account_id uuid primary key references public.afb_player_accounts(id) on delete cascade,
 save_json jsonb not null, captured_at timestamptz not null default now()
);
alter table afb_play_private.leases enable row level security;
alter table afb_play_private.original_careers enable row level security;
revoke all on all tables in schema afb_play_private from public, anon, authenticated;

create function afb_play_private.begin_play(p_session_token text,p_play_id uuid) returns jsonb
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

create function afb_play_private.heartbeat(p_session_token text,p_play_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a uuid:=public.afb_account_from_token(p_session_token); l afb_play_private.leases%rowtype;
begin
 if a is null then return jsonb_build_object('state','replaced'); end if;
 perform pg_advisory_xact_lock(hashtextextended(a::text,81731));
 select * into l from afb_play_private.leases where account_id=a for update;
 if not found or l.play_id is distinct from p_play_id or l.token_hash<>encode(extensions.digest(p_session_token,'sha256'),'hex') then return jsonb_build_object('state','replaced'); end if;
 update afb_play_private.leases set heartbeat=clock_timestamp() where account_id=a;
 return jsonb_build_object('state',case when l.pending_id is not null then 'handoff' else 'active' end,'revision',l.revision);
end; $$;

create function afb_play_private.save_career(p_session_token text,p_play_id uuid,p_revision bigint,p_save_json jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a uuid:=public.afb_account_from_token(p_session_token); l afb_play_private.leases%rowtype;
begin
 if a is null then return jsonb_build_object('ok',false,'reason','session_replaced'); end if;
 if p_save_json is null or jsonb_typeof(p_save_json)<>'object' or pg_column_size(p_save_json)>5242880 then raise exception 'save_invalid'; end if;
 perform pg_advisory_xact_lock(hashtextextended(a::text,81731));
 select * into l from afb_play_private.leases where account_id=a for update;
 if not found or l.play_id is distinct from p_play_id or l.token_hash<>encode(extensions.digest(p_session_token,'sha256'),'hex') then return jsonb_build_object('ok',false,'reason','session_replaced'); end if;
 if p_revision is distinct from l.revision then
  if l.revision=p_revision+1 and exists(select 1 from public.afb_player_saves where account_id=a and save_json=p_save_json) then return jsonb_build_object('ok',true,'revision',l.revision,'retry',true); end if;
  return jsonb_build_object('ok',false,'reason','save_conflict','revision',l.revision);
 end if;
 insert into public.afb_player_saves(account_id,save_json,updated_at) values(a,p_save_json,clock_timestamp())
 on conflict(account_id) do update set save_json=excluded.save_json,updated_at=excluded.updated_at;
 update afb_play_private.leases set revision=revision+1,heartbeat=clock_timestamp() where account_id=a;
 update public.afb_player_accounts set last_seen_at=clock_timestamp() where id=a;
 return jsonb_build_object('ok',true,'revision',l.revision+1);
end; $$;

create function afb_play_private.release_play(p_session_token text,p_play_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a uuid:=public.afb_account_from_token(p_session_token);
begin
 if a is null then return jsonb_build_object('ok',false); end if;
 perform pg_advisory_xact_lock(hashtextextended(a::text,81731));
 update afb_play_private.leases set play_id=null,token_hash=null,heartbeat=null where account_id=a and play_id=p_play_id and token_hash=encode(extensions.digest(p_session_token,'sha256'),'hex');
 return jsonb_build_object('ok',found);
end; $$;

create function public.afb_begin_play(p_session_token text,p_play_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select afb_play_private.begin_play(p_session_token,p_play_id); $$;
revoke all on function public.afb_begin_play(p_session_token text,p_play_id uuid) from public;
grant execute on function public.afb_begin_play(p_session_token text,p_play_id uuid) to anon,authenticated;
revoke all on function afb_play_private.begin_play(p_session_token text,p_play_id uuid) from public;
grant execute on function afb_play_private.begin_play(p_session_token text,p_play_id uuid) to anon,authenticated;

create function public.afb_play_heartbeat(p_session_token text,p_play_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select afb_play_private.heartbeat(p_session_token,p_play_id); $$;
revoke all on function public.afb_play_heartbeat(p_session_token text,p_play_id uuid) from public;
grant execute on function public.afb_play_heartbeat(p_session_token text,p_play_id uuid) to anon,authenticated;
revoke all on function afb_play_private.heartbeat(p_session_token text,p_play_id uuid) from public;
grant execute on function afb_play_private.heartbeat(p_session_token text,p_play_id uuid) to anon,authenticated;

create function public.afb_save_career(p_session_token text,p_play_id uuid,p_revision bigint,p_save_json jsonb) returns jsonb language sql security invoker set search_path='' as $$ select afb_play_private.save_career(p_session_token,p_play_id,p_revision,p_save_json); $$;
revoke all on function public.afb_save_career(p_session_token text,p_play_id uuid,p_revision bigint,p_save_json jsonb) from public;
grant execute on function public.afb_save_career(p_session_token text,p_play_id uuid,p_revision bigint,p_save_json jsonb) to anon,authenticated;
revoke all on function afb_play_private.save_career(p_session_token text,p_play_id uuid,p_revision bigint,p_save_json jsonb) from public;
grant execute on function afb_play_private.save_career(p_session_token text,p_play_id uuid,p_revision bigint,p_save_json jsonb) to anon,authenticated;

create function public.afb_release_play(p_session_token text,p_play_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select afb_play_private.release_play(p_session_token,p_play_id); $$;
revoke all on function public.afb_release_play(p_session_token text,p_play_id uuid) from public;
grant execute on function public.afb_release_play(p_session_token text,p_play_id uuid) to anon,authenticated;
revoke all on function afb_play_private.release_play(p_session_token text,p_play_id uuid) from public;
grant execute on function afb_play_private.release_play(p_session_token text,p_play_id uuid) to anon,authenticated;

-- Serialize legacy writes against activation and reject them only for enrolled accounts.
do $guard$
declare definition text;
begin
 definition:=replace(pg_get_functiondef('public.afb_set_save(text,jsonb)'::regprocedure),chr(13),'');
 if position('afb_play_private.leases' in definition)=0 then
  definition:=replace(definition,E'begin\n',$insert$begin
  if v_account is not null then
    perform pg_advisory_xact_lock(hashtextextended(v_account::text,81731));
    if exists(select 1 from afb_play_private.leases where account_id=v_account) then
      return jsonb_build_object('ok',false,'reason','client_update_required');
    end if;
  end if;
$insert$);
  execute definition;
 end if;
end; $guard$;
