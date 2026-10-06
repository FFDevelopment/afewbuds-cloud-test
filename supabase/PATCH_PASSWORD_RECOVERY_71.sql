create or replace function public.afb_password_reset_issue(p_username text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_username text := trim(coalesce(p_username, ''));
  v_account uuid;
  v_account_username text;
  v_email text;
  v_recent integer := 0;
  v_matches integer := 0;
  v_token text;
  v_exp timestamptz;
begin
  delete from public.afb_password_reset_tokens
   where expires_at < now() - interval '7 days'
      or (used_at is not null and used_at < now() - interval '7 days');

  if length(v_username) > 254 then
    return jsonb_build_object('deliver', false);
  end if;

  if position('@' in v_username) > 0 then
    -- Shared recovery addresses require a username; never choose an arbitrary account.
    select count(*) into v_matches from public.afb_player_accounts
     where lower(trim(email)) = lower(v_username);
    if v_matches != 1 then
      return jsonb_build_object('deliver', false);
    end if;
    select a.id, a.username, nullif(trim(a.email), '')
      into v_account, v_account_username, v_email
      from public.afb_player_accounts a
     where lower(trim(a.email)) = lower(v_username);
  else
    if v_username !~ '^[A-Za-z0-9_]{3,20}$' then
      return jsonb_build_object('deliver', false);
    end if;
    select a.id, a.username, nullif(trim(a.email), '')
      into v_account, v_account_username, v_email
      from public.afb_player_accounts a
     where lower(a.username) = lower(v_username)
     limit 1;
  end if;

  if v_account is null or v_email is null then
    return jsonb_build_object('deliver', false);
  end if;

  select count(*)::integer
    into v_recent
  from public.afb_password_reset_tokens r
  where r.account_id = v_account
    and r.created_at > now() - interval '15 minutes';

  if v_recent >= 3 then
    return jsonb_build_object('deliver', false, 'rate_limited', true);
  end if;

  -- Only the newest link remains valid.
  update public.afb_password_reset_tokens
     set used_at = now()
   where account_id = v_account
     and used_at is null
     and expires_at > now();

  v_token := encode(gen_random_bytes(32), 'hex');
  v_exp := now() + interval '30 minutes';

  insert into public.afb_password_reset_tokens(account_id, token_hash, expires_at)
  values (
    v_account,
    encode(digest(v_token, 'sha256'), 'hex'),
    v_exp
  );

  return jsonb_build_object(
    'deliver', true,
    'username', v_account_username,
    'email', v_email,
    'reset_token', v_token,
    'expires_at', v_exp
  );
end;
$$;

revoke execute on function public.afb_password_reset_issue(text) from public, anon, authenticated;
grant execute on function public.afb_password_reset_issue(text) to service_role;

