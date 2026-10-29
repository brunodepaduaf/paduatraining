-- Each session belongs to one student and one published training plan.
create table public.training_sessions (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 student_id uuid not null references public.profiles(id), plan_id uuid not null references public.training_plans(id),
 status text not null default 'in_progress' check (status in ('in_progress','completed')),
 started_at timestamptz not null default now(), completed_at timestamptz,
 check ((status = 'completed') = (completed_at is not null))
);
create unique index training_sessions_one_open_idx on public.training_sessions(plan_id, student_id) where status = 'in_progress';
create index training_sessions_student_started_idx on public.training_sessions(organization_id, student_id, started_at desc);
create table public.training_session_items (
 id uuid primary key default gen_random_uuid(), session_id uuid not null references public.training_sessions(id),
 plan_item_id uuid not null references public.training_plan_items(id), completed boolean not null default false,
 unique(session_id, plan_item_id)
);
alter table public.training_sessions enable row level security;
alter table public.training_session_items enable row level security;
create policy training_sessions_student_read on public.training_sessions for select to authenticated using (private.can_read_own_training(organization_id, student_id));
create policy training_sessions_student_insert on public.training_sessions for insert to authenticated with check (private.can_read_own_training(organization_id, student_id) and status = 'in_progress');
create policy training_sessions_student_update on public.training_sessions for update to authenticated using (private.can_read_own_training(organization_id, student_id)) with check (private.can_read_own_training(organization_id, student_id));
create policy training_session_items_student_read on public.training_session_items for select to authenticated using (exists(select 1 from public.training_sessions s where s.id = session_id and private.can_read_own_training(s.organization_id, s.student_id)));
create policy training_session_items_student_insert on public.training_session_items for insert to authenticated with check (exists(select 1 from public.training_sessions s where s.id = session_id and s.status = 'in_progress' and private.can_read_own_training(s.organization_id, s.student_id)));
create policy training_session_items_student_update on public.training_session_items for update to authenticated using (exists(select 1 from public.training_sessions s where s.id = session_id and s.status = 'in_progress' and private.can_read_own_training(s.organization_id, s.student_id))) with check (exists(select 1 from public.training_sessions s where s.id = session_id and s.status = 'in_progress' and private.can_read_own_training(s.organization_id, s.student_id)));
revoke all on public.training_sessions, public.training_session_items from public, anon, authenticated;
grant select, insert, update on public.training_sessions, public.training_session_items to authenticated;

create function private.guard_training_session() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if tg_op = 'INSERT' then
   if new.status <> 'in_progress' or new.completed_at is not null then raise exception 'session must start in progress'; end if;
   perform 1 from public.training_plans p where p.id = new.plan_id and p.organization_id = new.organization_id and p.student_id = new.student_id and p.status = 'published' for update;
   if not found then raise exception 'session requires an assigned published plan'; end if;
   new.started_at := now();
   return new;
 end if;
 if old.status = 'completed' then raise exception 'completed sessions are immutable'; end if;
 if (new.id,new.organization_id,new.student_id,new.plan_id,new.started_at) is distinct from (old.id,old.organization_id,old.student_id,old.plan_id,old.started_at) then raise exception 'session identity is immutable'; end if;
 if new.status = 'completed' then
   if exists(select 1 from public.training_plan_items p left join public.training_session_items i on i.plan_item_id = p.id and i.session_id = old.id where p.plan_id = old.plan_id and coalesce(i.completed,false) = false) then raise exception 'complete every exercise first'; end if;
   new.completed_at := now();
 end if;
 return new;
end $$;
create function private.guard_training_session_item() returns trigger language plpgsql security definer set search_path = '' as $$
declare session_status text; target_plan uuid;
begin
 select status,plan_id into session_status,target_plan from public.training_sessions where id = case when tg_op='INSERT' then new.session_id else old.session_id end for update;
 if session_status is distinct from 'in_progress' then raise exception 'completed sessions are immutable'; end if;
 if tg_op='UPDATE' and (new.id,new.session_id,new.plan_item_id) is distinct from (old.id,old.session_id,old.plan_item_id) then raise exception 'session item identity is immutable'; end if;
 if not exists(select 1 from public.training_plan_items where id = new.plan_item_id and plan_id = target_plan) then raise exception 'item must belong to the session plan'; end if;
 return new;
end $$;
create trigger training_session_guard before insert or update on public.training_sessions for each row execute function private.guard_training_session();
create trigger training_session_item_guard before insert or update on public.training_session_items for each row execute function private.guard_training_session_item();
revoke all on function private.guard_training_session(), private.guard_training_session_item() from public;

-- Staff receive only a scoped summary, with each consultation audited.
create function public.get_training_session_summary(target_student uuid, target_organization uuid)
returns table (session_id uuid, plan_title text, started_at timestamptz, completed_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
 if not private.can_read_staff_training(target_organization, target_student) then raise exception 'not authorized'; end if;
 insert into public.audit_logs(organization_id,actor_id,action,entity_type,entity_id,metadata)
 values (target_organization, auth.uid(), 'training_sessions.reviewed', 'student', target_student, '{}'::jsonb);
 return query select s.id,p.title,s.started_at,s.completed_at from public.training_sessions s join public.training_plans p on p.id=s.plan_id where s.organization_id=target_organization and s.student_id=target_student and s.status='completed' order by s.completed_at desc;
end $$;
revoke all on function public.get_training_session_summary(uuid,uuid) from public, anon;
grant execute on function public.get_training_session_summary(uuid,uuid) to authenticated;
