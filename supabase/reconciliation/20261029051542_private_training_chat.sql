-- Private messages are limited to a currently linked trainer and active student.
create table public.training_chat_messages (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 trainer_id uuid not null references public.profiles(id), student_id uuid not null references public.profiles(id),
 sender_id uuid not null references public.profiles(id), body text not null check (char_length(trim(body)) between 1 and 2000),
 created_at timestamptz not null default now(), check (sender_id in (trainer_id, student_id))
);
create index training_chat_conversation_idx on public.training_chat_messages(organization_id, trainer_id, student_id, created_at desc, id desc);
create function private.can_use_training_chat(org uuid, trainer uuid, student uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select coalesce((select auth.uid()) in (trainer,student)
 and private.member_role_for(org,trainer) = 'trainer'::public.member_role
 and private.member_role_for(org,student) = 'student'::public.member_role
 and exists(select 1 from public.trainer_students ts where ts.organization_id=org and ts.trainer_id=trainer and ts.student_id=student and ts.archived_at is null)
 and private.has_active_student_access(org,student), false);
$$;
revoke all on function private.can_use_training_chat(uuid,uuid,uuid) from public;
grant execute on function private.can_use_training_chat(uuid,uuid,uuid) to authenticated;
alter table public.training_chat_messages enable row level security;
create policy training_chat_read on public.training_chat_messages for select to authenticated using (private.can_use_training_chat(organization_id,trainer_id,student_id));
create policy training_chat_send on public.training_chat_messages for insert to authenticated with check (sender_id=(select auth.uid()) and private.can_use_training_chat(organization_id,trainer_id,student_id));
-- Clinical context may appear in text: all access goes through the audited RPCs.
revoke all on public.training_chat_messages from public, anon, authenticated;
create function private.prevent_training_chat_mutation() returns trigger language plpgsql set search_path = '' as $$
begin raise exception 'chat messages are immutable'; end $$;
create trigger training_chat_immutable before update or delete on public.training_chat_messages for each row execute function private.prevent_training_chat_mutation();
revoke all on function private.prevent_training_chat_mutation() from public;

create function public.get_training_chat_contacts(target_organization uuid)
returns table(person_id uuid, full_name text) language plpgsql security definer set search_path = '' as $$
declare role_name public.member_role;
begin
 role_name := private.member_role_for(target_organization,auth.uid());
 if role_name not in ('student'::public.member_role,'trainer'::public.member_role) or role_name is null then raise exception 'not authorized'; end if;
 return query select p.id,p.full_name from public.trainer_students ts
 join public.profiles p on p.id=case when role_name='student' then ts.trainer_id else ts.student_id end
 where ts.organization_id=target_organization and ts.archived_at is null
   and ((role_name='student' and ts.student_id=auth.uid()) or (role_name='trainer' and ts.trainer_id=auth.uid()))
   and private.can_use_training_chat(ts.organization_id,ts.trainer_id,ts.student_id)
 order by p.full_name,p.id;
end $$;
create function public.send_training_chat_message(target_organization uuid, other_person uuid, message_text text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare role_name public.member_role; trainer uuid; student uuid; message_id uuid;
begin
 role_name := private.member_role_for(target_organization,auth.uid());
 if role_name='student' then trainer:=other_person; student:=auth.uid();
 elsif role_name='trainer' then trainer:=auth.uid(); student:=other_person;
 else raise exception 'not authorized'; end if;
 if not private.can_use_training_chat(target_organization,trainer,student) then raise exception 'not authorized'; end if;
 insert into public.training_chat_messages(organization_id,trainer_id,student_id,sender_id,body)
 values(target_organization,trainer,student,auth.uid(),trim(message_text)) returning id into message_id;
 insert into public.audit_logs(organization_id,actor_id,action,entity_type,entity_id,metadata)
 values(target_organization,auth.uid(),'training_chat.sent','training_chat_message',message_id,'{}'::jsonb);
 return message_id;
end $$;
create function public.get_training_chat_messages(target_organization uuid, other_person uuid)
returns table(id uuid, sender_id uuid, body text, created_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare role_name public.member_role; trainer uuid; student uuid;
begin
 role_name := private.member_role_for(target_organization,auth.uid());
 if role_name='student' then trainer:=other_person; student:=auth.uid();
 elsif role_name='trainer' then trainer:=auth.uid(); student:=other_person;
 else raise exception 'not authorized'; end if;
 if not private.can_use_training_chat(target_organization,trainer,student) then raise exception 'not authorized'; end if;
 insert into public.audit_logs(organization_id,actor_id,action,entity_type,entity_id,metadata)
 values(target_organization,auth.uid(),'training_chat.reviewed','profile',other_person,'{}'::jsonb);
 return query select m.id,m.sender_id,m.body,m.created_at from
   (select c.id,c.sender_id,c.body,c.created_at from public.training_chat_messages c where c.organization_id=target_organization and c.trainer_id=trainer and c.student_id=student order by c.created_at desc,c.id desc limit 100) m order by m.created_at,m.id;
end $$;
revoke all on function public.get_training_chat_contacts(uuid), public.send_training_chat_message(uuid,uuid,text), public.get_training_chat_messages(uuid,uuid) from public, anon;
grant execute on function public.get_training_chat_contacts(uuid), public.send_training_chat_message(uuid,uuid,text), public.get_training_chat_messages(uuid,uuid) to authenticated;
