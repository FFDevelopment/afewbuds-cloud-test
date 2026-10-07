create or replace function afb_play_private.save_career(p_session_token text,p_play_id uuid,p_revision bigint,p_save_json jsonb) returns jsonb
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
