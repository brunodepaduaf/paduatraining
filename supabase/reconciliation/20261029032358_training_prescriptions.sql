-- One ordered workout per version. Items snapshot exercise names/instructions when added.
create table public.training_plans (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 student_id uuid not null references public.profiles(id), created_by uuid not null references public.profiles(id),
 title text not null check (char_length(trim(title)) between 2 and 160), version integer not null check (version > 0),
 status text not null default 'draft' check (status in ('draft','published','archived')),
 published_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique (organization_id, student_id, version), check ((status = 'draft' and published_at is null) or (status in ('published','archived') and published_at is not null))
);
create table public.training_plan_items (
 id uuid primary key default gen_random_uuid(), plan_id uuid not null references public.training_plans(id) on delete cascade,
 exercise_id uuid not null references public.exercises(id), position integer not null check (position > 0),
 exercise_name text not null, exercise_instructions text not null default '', sets integer not null check (sets between 1 and 100),
 repetitions text not null check (char_length(trim(repetitions)) between 1 and 80),
 unique (plan_id, position)
);
create index training_plans_org_student_idx on public.training_plans(organization_id, student_id, status);

create function private.can_manage_training(org uuid, student uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select coalesce(private.member_role_for(org, student) = 'student'::public.member_role and
 (private.is_org_owner(org) or (private.member_role_for(org, (select auth.uid())) = 'trainer'::public.member_role
 and exists (select 1 from public.trainer_students ts where ts.organization_id = org and ts.student_id = student and ts.trainer_id = (select auth.uid()) and ts.archived_at is null)
 and private.has_active_student_access(org, student))), false);
$$;
create function private.can_read_staff_training(org uuid, student uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select coalesce(private.is_org_owner(org) or private.can_manage_training(org, student), false);
$$;
create function private.can_read_own_training(org uuid, student uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select student = (select auth.uid()) and coalesce(private.member_role_for(org, student) = 'student'::public.member_role and private.has_active_student_access(org, student), false);
$$;
revoke all on function private.can_manage_training(uuid,uuid), private.can_read_staff_training(uuid,uuid), private.can_read_own_training(uuid,uuid) from public;
grant execute on function private.can_manage_training(uuid,uuid), private.can_read_staff_training(uuid,uuid), private.can_read_own_training(uuid,uuid) to authenticated;

alter table public.training_plans enable row level security;
alter table public.training_plan_items enable row level security;
create policy training_plans_staff_read on public.training_plans for select to authenticated using (private.can_read_staff_training(organization_id, student_id));
create policy training_plans_student_read on public.training_plans for select to authenticated using (status = 'published' and private.can_read_own_training(organization_id, student_id));
create policy training_plans_staff_insert on public.training_plans for insert to authenticated with check (private.can_manage_training(organization_id, student_id) and created_by = (select auth.uid()) and status = 'draft');
create policy training_plans_staff_update on public.training_plans for update to authenticated using (private.can_manage_training(organization_id, student_id)) with check (private.can_manage_training(organization_id, student_id));
create policy training_plans_staff_delete on public.training_plans for delete to authenticated using (status = 'draft' and private.can_manage_training(organization_id, student_id));
create policy training_items_read on public.training_plan_items for select to authenticated using (exists(select 1 from public.training_plans p where p.id = plan_id));
create policy training_items_staff_insert on public.training_plan_items for insert to authenticated with check (exists(select 1 from public.training_plans p where p.id = plan_id and p.status = 'draft' and private.can_manage_training(p.organization_id, p.student_id)));
create policy training_items_staff_update on public.training_plan_items for update to authenticated using (exists(select 1 from public.training_plans p where p.id = plan_id and p.status = 'draft' and private.can_manage_training(p.organization_id, p.student_id))) with check (exists(select 1 from public.training_plans p where p.id = plan_id and p.status = 'draft' and private.can_manage_training(p.organization_id, p.student_id)));
create policy training_items_staff_delete on public.training_plan_items for delete to authenticated using (exists(select 1 from public.training_plans p where p.id = plan_id and p.status = 'draft' and private.can_manage_training(p.organization_id, p.student_id)));
revoke all on public.training_plans, public.training_plan_items from public, anon, authenticated;
grant select, insert, update, delete on public.training_plans, public.training_plan_items to authenticated;

create function private.guard_training_plan() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if tg_op = 'DELETE' then if old.status <> 'draft' then raise exception 'published plans cannot be deleted'; end if; return old; end if;
 if tg_op = 'INSERT' then if new.status <> 'draft' or new.published_at is not null then raise exception 'plans must start as drafts'; end if; return new; end if;
 if (new.id,new.organization_id,new.student_id,new.created_by,new.created_at) is distinct from (old.id,old.organization_id,old.student_id,old.created_by,old.created_at) then raise exception 'plan identity is immutable'; end if;
 if old.status = 'archived' then raise exception 'archived plans are immutable'; end if;
 if old.status = 'published' then
   if new.status <> 'archived' or (to_jsonb(new) - array['status','updated_at']) is distinct from (to_jsonb(old) - array['status','updated_at']) then raise exception 'published plans are immutable'; end if;
 elsif new.status = 'archived' then raise exception 'drafts cannot be archived';
 elsif new.status = 'published' then
   if not exists(select 1 from public.training_plan_items where plan_id = old.id) then raise exception 'plan requires an exercise'; end if;
   new.published_at := now();
 end if;
 return new;
end $$;
create function private.guard_training_item() returns trigger language plpgsql security definer set search_path = '' as $$
declare plan_org uuid; plan_status text; exercise_row public.exercises%rowtype;
begin
 select organization_id,status into plan_org,plan_status from public.training_plans where id = case when tg_op = 'INSERT' then new.plan_id else old.plan_id end for update;
 if plan_status is null and tg_op = 'DELETE' then return old; end if;
 if plan_status is distinct from 'draft' then raise exception 'published plan items are immutable'; end if;
 if tg_op = 'DELETE' then return old; end if;
 if tg_op = 'UPDATE' and new.plan_id is distinct from old.plan_id then raise exception 'item cannot change plan'; end if;
 select * into exercise_row from public.exercises where id = new.exercise_id and organization_id = plan_org and archived_at is null;
 if not found then raise exception 'exercise must be active and belong to the plan organization'; end if;
 new.exercise_name := exercise_row.name; new.exercise_instructions := exercise_row.instructions;
 return new;
end $$;
create trigger training_plan_guard before insert or update or delete on public.training_plans for each row execute function private.guard_training_plan();
create trigger training_plan_updated before update on public.training_plans for each row execute function private.set_updated_at();
create trigger training_item_guard before insert or update or delete on public.training_plan_items for each row execute function private.guard_training_item();
revoke all on function private.guard_training_plan(), private.guard_training_item() from public;
-- Record lifecycle events without exercise instructions or other personal content.
create function private.audit_training_plan() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.audit_logs(organization_id,actor_id,action,entity_type,entity_id,metadata)
 values (coalesce(new.organization_id,old.organization_id), auth.uid(), 'training_plan.' || lower(tg_op), 'training_plan', coalesce(new.id,old.id), jsonb_build_object('status',coalesce(new.status,old.status)));
 return coalesce(new,old);
end $$;
create trigger training_plan_audit after insert or update or delete on public.training_plans for each row execute function private.audit_training_plan();
revoke all on function private.audit_training_plan() from public;
