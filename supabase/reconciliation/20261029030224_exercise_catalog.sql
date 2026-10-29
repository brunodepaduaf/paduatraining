-- Organization-scoped exercise catalog, without student or public access.
create table public.exercises (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id),
 name text not null check (char_length(trim(name)) between 2 and 160),
 instructions text not null default '' check (char_length(instructions) <= 4000),
 created_by uuid not null references public.profiles(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 archived_at timestamptz
);
create unique index exercises_active_name_idx on public.exercises (organization_id, lower(trim(name))) where archived_at is null;
create index exercises_org_created_idx on public.exercises (organization_id, created_at desc);
create function private.can_manage_exercises(target_organization uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select coalesce(private.member_role_for(target_organization, (select auth.uid())) in ('owner'::public.member_role, 'trainer'::public.member_role), false);
$$;
revoke all on function private.can_manage_exercises(uuid) from public;
grant execute on function private.can_manage_exercises(uuid) to authenticated;
alter table public.exercises enable row level security;
create policy exercises_staff_read on public.exercises for select to authenticated
 using (private.can_manage_exercises(organization_id));
create policy exercises_staff_insert on public.exercises for insert to authenticated
 with check (private.can_manage_exercises(organization_id) and created_by = (select auth.uid()) and archived_at is null);
create policy exercises_staff_update on public.exercises for update to authenticated
 using (private.can_manage_exercises(organization_id))
 with check (private.can_manage_exercises(organization_id));
grant select, insert, update on public.exercises to authenticated;

create function private.guard_exercise() returns trigger language plpgsql set search_path = '' as $$
begin
 if old.archived_at is not null then raise exception 'archived exercises are immutable'; end if;
 if (new.id, new.organization_id, new.created_by, new.created_at) is distinct from (old.id, old.organization_id, old.created_by, old.created_at) then raise exception 'exercise identity is immutable'; end if;
 if new.archived_at is not null and (new.name, new.instructions) is distinct from (old.name, old.instructions) then raise exception 'archive and editing must be separate actions'; end if;
 return new;
end $$;
create trigger exercises_guard before update on public.exercises for each row execute function private.guard_exercise();
create trigger exercises_updated_at before update on public.exercises for each row execute function private.set_updated_at();
revoke all on function private.guard_exercise() from public;
