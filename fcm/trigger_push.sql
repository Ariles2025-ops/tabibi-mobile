-- Trigger: pousse une notification FCM a chaque insert dans public.notifications.
-- Prerequis: secrets Firebase poses sur l'edge function send-push + ce secret Vault.

-- 1) stocker la cle service_role dans le Vault (Settings > API > service_role)
select vault.create_secret('<COLLE_ICI_TA_CLE_SERVICE_ROLE>', 'service_role_key', 'Pour le trigger push');

-- 2) fonction + trigger
create or replace function public.notif_push_hook()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_key text;
begin
  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'service_role_key' limit 1;
  if v_key is null then return new; end if;
  perform net.http_post(
    url := 'https://pudugodhiofqrctcdwfl.supabase.co/functions/v1/send-push',
    body := jsonb_build_object('user_id', new.user_id, 'title', new.title,
                               'body', new.message, 'data', coalesce(new.data, '{}'::jsonb)),
    headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || v_key)
  );
  return new;
end; $$;

drop trigger if exists trg_notif_push on public.notifications;
create trigger trg_notif_push after insert on public.notifications
for each row execute function public.notif_push_hook();
