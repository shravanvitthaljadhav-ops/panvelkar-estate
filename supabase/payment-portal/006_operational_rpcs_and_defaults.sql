-- Payment portal operational RPCs and V2.0 default templates.
begin;
alter table public.payment_templates add column if not exists system_key text;
create unique index if not exists payment_templates_system_key_uidx
  on public.payment_templates(system_key) where system_key is not null;

insert into public.payment_templates(system_key,name,category,message,file_name,is_default,active)
values
('default_maintenance','Maintenance Reminder','Default',$maintenance$
*📌 देखभाल शुल्क भरण्याबाबत नम्र सूचना*

*महत्त्वाची सूचना:*
खाली नमूद केलेली रक्कम 30 सप्टेंबर 2026 पर्यंतची थकबाकी तसेच ऑक्टोबर 2026 महिन्याचे देखभाल शुल्क यांची एकत्रित देय रक्कम आहे.

ज्या सभासदांनी 1 ऑक्टोबर 2026 नंतर देखभाल शुल्क जमा केले आहे, त्यांनी कृपया हा संदेश दुर्लक्षित करावा.

*👤 सदनिकेचा क्रमांक व सभासदाचे नाव:* {{FLAT}} {{NAME}}
*💰 देय रक्कम:* ₹{{AMOUNT}}/-
*📅 अंतिम दिनांक:* 15 ऑक्टोबर 2026

सर्व संबंधित सभासदांनी कृपया सदर देय रक्कम अंतिम दिनांकापूर्वी जमा करून सहकार्य करावे, ही नम्र विनंती.

*रक्कम जमा केल्यानंतर कृपया UTR क्रमांक / पेमेंटचा स्क्रीनशॉट*
*📱 91568 22501 या WhatsApp क्रमांकावर पाठवावा.*

*काही शंका किंवा अडचण असल्यास कृपया खालील ई-मेलवर कळवावे:*
*📧 panvelkar.stanford@gmail.com*

आपल्या सहकार्याबद्दल धन्यवाद. 🙏
*सोसायटी व्यवस्थापन समिती*
$maintenance$,'',true,true),
('default_part_payment','Part Payment Follow-up','Default',$partial$
Dear {{NAME}},

We acknowledge receipt of ₹{{RECEIVED}} against your maintenance demand of ₹{{AMOUNT}} for {{FLAT}}. The outstanding balance is ₹{{BALANCE}}.

Kindly clear the remaining amount at the earliest. Thank you.

Society Management Committee
$partial$,'',true,true)
on conflict(system_key) do nothing;

create or replace function public.payment_bulk_set_outstanding(p_rows jsonb)
returns integer language plpgsql security invoker set search_path = '' as $$
declare r jsonb; v_count integer:=0; v_id uuid; v_out numeric;
begin
 perform public.payment_assert_admin();
 if jsonb_typeof(p_rows)<>'array' then raise exception 'Outstanding upload must be a JSON array'; end if;
 for r in select value from jsonb_array_elements(p_rows) loop
  v_id:=(r->>'unit_id')::uuid; v_out:=(r->>'outstanding')::numeric;
  if v_out is null or v_out<0 then raise exception 'Invalid outstanding amount'; end if;
  update public.payment_units set total_demand=total_received+v_out,updated_at=now(),updated_by=auth.uid() where id=v_id;
  if not found then raise exception 'Unit not found in outstanding upload: %',v_id; end if;
  v_count:=v_count+1;
 end loop;
 return v_count;
end; $$;

create or replace function public.payment_reset_whatsapp_status()
returns integer language plpgsql security invoker set search_path = '' as $$
declare v_count integer;
begin
 perform public.payment_assert_admin();
 update public.payment_units set whatsapp_status=case when outstanding<=0 then 'Not Required' else 'Pending' end,
  whatsapp_sent_at=null,updated_at=now(),updated_by=auth.uid();
 get diagnostics v_count=row_count;
 return v_count;
end; $$;

create or replace function public.payment_expire_whatsapp_status()
returns integer language plpgsql security invoker set search_path = '' as $$
declare v_count integer;
begin
 perform public.payment_assert_admin();
 update public.payment_units set whatsapp_status=case when outstanding<=0 then 'Not Required' else 'Pending' end,
  whatsapp_sent_at=null,updated_at=now(),updated_by=auth.uid()
 where (whatsapp_status='Sent' and whatsapp_sent_at<=now()-interval '24 hours')
    or (outstanding<=0 and whatsapp_status<>'Not Required');
 get diagnostics v_count=row_count;
 return v_count;
end; $$;

revoke all on function public.payment_bulk_set_outstanding(jsonb) from public,anon;
revoke all on function public.payment_reset_whatsapp_status() from public,anon;
revoke all on function public.payment_expire_whatsapp_status() from public,anon;
grant execute on function public.payment_bulk_set_outstanding(jsonb) to authenticated;
grant execute on function public.payment_reset_whatsapp_status() to authenticated;
grant execute on function public.payment_expire_whatsapp_status() to authenticated;
commit;