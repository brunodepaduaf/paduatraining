-- 20261026162337 initial_foundation
-- Sprint 0: tenancy, identity and an auditable authorization base.
create schema if not exists private;

create type public.member_role as enum ('owner', 'trainer', 'student');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz
);

create table public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  profile_id uuid not null references public.profiles(id),
  role public.member_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (organization_id, profile_id)
);

create table public.trainer_students (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  trainer_id uuid not null references public.profiles(id),
  student_id uuid not null references public.profiles(id),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (organization_id, trainer_id, student_id),
  check (trainer_id <> student_id)
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index organization_members_profile_idx on public.organization_members(profile_id) where archived_at is null;
create index trainer_students_trainer_idx on public.trainer_students(trainer_id) where archived_at is null;
create index trainer_students_student_idx on public.trainer_students(student_id) where archived_at is null;
create index audit_logs_organization_created_idx on public.audit_logs(organization_id, created_at desc);

create or replace function private.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$ begin new.updated_at = now(); return new; end; $$;

create trigger profiles_updated_at before update on public.profiles for each row execute function private.set_updated_at();
create trigger organizations_updated_at before update on public.organizations for each row execute function private.set_updated_at();
create trigger organization_members_updated_at before update on public.organization_members for each row execute function private.set_updated_at();
create trigger trainer_students_updated_at before update on public.trainer_students for each row execute function private.set_updated_at();

-- Auth trigger is intentionally narrow: client metadata cannot assign a role or organization.
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name) values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''));
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function private.handle_new_user();

create or replace function private.member_role_for(target_organization uuid, target_profile uuid)
returns public.member_role
language sql stable security definer set search_path = ''
as $$ select role from public.organization_members where organization_id = target_organization and profile_id = target_profile and archived_at is null limit 1; $$;

create or replace function private.is_org_owner(target_organization uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$ select private.member_role_for(target_organization, (select auth.uid())) = 'owner'::public.member_role; $$;

create or replace function private.is_org_member(target_organization uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$ select private.member_role_for(target_organization, (select auth.uid())) is not null; $$;

create or replace function private.can_read_profile(target_profile uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select target_profile = (select auth.uid())
  or exists (select 1 from public.trainer_students ts where ts.archived_at is null and ts.student_id = target_profile and ts.trainer_id = (select auth.uid()))
  or exists (select 1 from public.organization_members om where om.profile_id = target_profile and om.archived_at is null and private.is_org_owner(om.organization_id));
$$;

revoke all on schema private from public;
revoke all on all functions in schema private from public;
grant usage on schema private to authenticated;
grant execute on function private.is_org_owner(uuid), private.is_org_member(uuid), private.can_read_profile(uuid) to authenticated;

alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.trainer_students enable row level security;
alter table public.audit_logs enable row level security;

create policy "read authorized profiles" on public.profiles for select to authenticated using (private.can_read_profile(id));
create policy "update own profile" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "read member organizations" on public.organizations for select to authenticated using (private.is_org_member(id));
create policy "create own organization" on public.organizations for insert to authenticated with check (created_by = (select auth.uid()));
create policy "owners update organization" on public.organizations for update to authenticated using (private.is_org_owner(id)) with check (private.is_org_owner(id));

create policy "read organization members" on public.organization_members for select to authenticated using (private.is_org_member(organization_id));
create policy "owners manage organization members" on public.organization_members for all to authenticated using (private.is_org_owner(organization_id)) with check (private.is_org_owner(organization_id));

create policy "read permitted trainer links" on public.trainer_students for select to authenticated using (trainer_id = (select auth.uid()) or student_id = (select auth.uid()) or private.is_org_owner(organization_id));
create policy "trainers or owners create own links" on public.trainer_students for insert to authenticated with check ((trainer_id = (select auth.uid()) or private.is_org_owner(organization_id)) and private.is_org_member(organization_id));
create policy "trainers or owners update links" on public.trainer_students for update to authenticated using (trainer_id = (select auth.uid()) or private.is_org_owner(organization_id)) with check ((trainer_id = (select auth.uid()) or private.is_org_owner(organization_id)) and private.is_org_member(organization_id));

create policy "owners read audit trail" on public.audit_logs for select to authenticated using (private.is_org_owner(organization_id));

-- Sensitive media are private; policies will be tightened with the assessment domain in Sprint 8.
insert into storage.buckets (id, name, public) values ('assessment-photos', 'assessment-photos', false) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('exercise-media', 'exercise-media', false) on conflict (id) do nothing;

grant select, insert, update, delete on public.profiles, public.organizations, public.organization_members, public.trainer_students, public.audit_logs to authenticated;


-- 20261026162553 foundation_performance_indexes
-- Cover foreign keys used by ownership/audit joins and avoid overlapping SELECT policies.
create index organizations_created_by_idx on public.organizations(created_by);
create index trainer_students_created_by_idx on public.trainer_students(created_by);
create index audit_logs_actor_id_idx on public.audit_logs(actor_id);

drop policy "owners manage organization members" on public.organization_members;
create policy "owners insert organization members" on public.organization_members
  for insert to authenticated
  with check (private.is_org_owner(organization_id));
create policy "owners update organization members" on public.organization_members
  for update to authenticated
  using (private.is_org_owner(organization_id))
  with check (private.is_org_owner(organization_id));
create policy "owners delete organization members" on public.organization_members
  for delete to authenticated
  using (private.is_org_owner(organization_id));


-- 20261026164705 sprint_1_auth_hardening
-- Students cannot enumerate other members; trainers can only see themselves and assigned students.
create or replace function private.can_read_member(target_organization uuid, target_profile uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select target_profile = (select auth.uid())
    or private.is_org_owner(target_organization)
    or exists (
      select 1 from public.trainer_students ts
      where ts.organization_id = target_organization
        and ts.archived_at is null
        and ts.trainer_id = (select auth.uid())
        and ts.student_id = target_profile
    );
$$;

create or replace function private.can_manage_trainer_link(
  target_organization uuid,
  target_trainer uuid,
  target_student uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select private.is_org_owner(target_organization)
    or (
      target_trainer = (select auth.uid())
      and private.member_role_for(target_organization, (select auth.uid())) = 'trainer'::public.member_role
      and private.member_role_for(target_organization, target_student) = 'student'::public.member_role
    );
$$;

revoke all on function private.can_read_member(uuid, uuid), private.can_manage_trainer_link(uuid, uuid, uuid) from public;
grant execute on function private.can_read_member(uuid, uuid), private.can_manage_trainer_link(uuid, uuid, uuid) to authenticated;

drop policy "read organization members" on public.organization_members;
create policy "read own or staff organization members" on public.organization_members
  for select to authenticated
  using (private.can_read_member(organization_id, profile_id));

drop policy "trainers or owners create own links" on public.trainer_students;
drop policy "trainers or owners update links" on public.trainer_students;
create policy "authorized staff create trainer links" on public.trainer_students
  for insert to authenticated
  with check (private.can_manage_trainer_link(organization_id, trainer_id, student_id));
create policy "authorized staff update trainer links" on public.trainer_students
  for update to authenticated
  using (private.can_manage_trainer_link(organization_id, trainer_id, student_id))
  with check (private.can_manage_trainer_link(organization_id, trainer_id, student_id));


-- 20261026175119 sprint_2_access_control
-- Sprint 2: auditable, manual access periods. A period is never deleted so its
-- payment/access history remains available to the organization owner.
create type public.access_period_status as enum ('pending', 'active', 'expired', 'blocked');

create table public.access_periods (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.profiles(id),
  starts_at timestamptz not null,
  ends_at timestamptz,
  status public.access_period_status not null default 'pending',
  responsible_id uuid not null references public.profiles(id),
  note text not null default '' check (char_length(note) <= 2000),
  created_by uuid not null references public.profiles(id),
  updated_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at >= starts_at)
);

create index access_periods_student_status_idx
  on public.access_periods (organization_id, student_id, status, ends_at desc);
create index access_periods_organization_status_idx
  on public.access_periods (organization_id, status, starts_at desc);

-- Owners may manage links, but both endpoints must retain their real roles.
create or replace function private.validate_trainer_student_roles()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if private.member_role_for(new.organization_id, new.trainer_id) is distinct from 'trainer'::public.member_role then
    raise exception 'trainer_students trainer must be an active trainer member of its organization';
  end if;
  if private.member_role_for(new.organization_id, new.student_id) is distinct from 'student'::public.member_role then
    raise exception 'trainer_students student must be an active student member of its organization';
  end if;
  return new;
end;
$$;

create or replace function private.audit_trainer_student_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, metadata)
  values (
    new.organization_id, auth.uid(),
    case when tg_op = 'INSERT' then 'trainer_student.created' else 'trainer_student.updated' end,
    'trainer_student', new.id,
    jsonb_build_object('trainer_id', new.trainer_id, 'student_id', new.student_id, 'archived_at', new.archived_at)
  );
  return new;
end;
$$;

create trigger trainer_students_validate_roles before insert or update on public.trainer_students
  for each row execute function private.validate_trainer_student_roles();
create trigger trainer_students_audit after insert or update on public.trainer_students
  for each row execute function private.audit_trainer_student_change();

create or replace function private.can_read_student_access(
  target_organization uuid,
  target_student uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select target_student = (select auth.uid())
    or private.is_org_owner(target_organization)
    or exists (
      select 1 from public.trainer_students ts
      where ts.organization_id = target_organization
        and ts.student_id = target_student
        and ts.trainer_id = (select auth.uid())
        and ts.archived_at is null
    );
$$;

create or replace function private.can_manage_student_access(
  target_organization uuid,
  target_student uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select private.is_org_owner(target_organization)
    or (
      private.member_role_for(target_organization, (select auth.uid())) = 'trainer'::public.member_role
      and exists (
        select 1 from public.trainer_students ts
        where ts.organization_id = target_organization
          and ts.student_id = target_student
          and ts.trainer_id = (select auth.uid())
          and ts.archived_at is null
      )
    );
$$;

-- Validates foreign relationships independently of RLS, preventing a staff
-- member from attaching an access period to a profile outside this organization.
create or replace function private.validate_access_period()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if private.member_role_for(new.organization_id, new.student_id) is distinct from 'student'::public.member_role then
    raise exception 'access_period student must be an active student member of its organization';
  end if;

  if not coalesce(private.member_role_for(new.organization_id, new.responsible_id) in ('owner'::public.member_role, 'trainer'::public.member_role), false) then
    raise exception 'access_period responsible must be an active owner or trainer member of its organization';
  end if;

  if tg_op = 'UPDATE' and (new.created_by is distinct from old.created_by or new.created_at is distinct from old.created_at) then
    raise exception 'access_period creation attribution is immutable';
  end if;

  return new;
end;
$$;

create or replace function private.audit_access_period_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  audit_action text;
begin
  audit_action := case when tg_op = 'INSERT' then 'access_period.created' else 'access_period.updated' end;

  insert into public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, metadata)
  values (
    new.organization_id,
    coalesce(auth.uid(), new.updated_by),
    audit_action,
    'access_period',
    new.id,
    jsonb_build_object(
      'student_id', new.student_id,
      'status', new.status,
      'starts_at', new.starts_at,
      'ends_at', new.ends_at,
      'responsible_id', new.responsible_id,
      'previous_status', case when tg_op = 'UPDATE' then old.status else null end
    )
  );
  return new;
end;
$$;

create trigger access_periods_validate before insert or update on public.access_periods
  for each row execute function private.validate_access_period();
create trigger access_periods_updated_at before update on public.access_periods
  for each row execute function private.set_updated_at();
create trigger access_periods_audit after insert or update on public.access_periods
  for each row execute function private.audit_access_period_change();

revoke all on function private.can_read_student_access(uuid, uuid), private.can_manage_student_access(uuid, uuid), private.validate_access_period(), private.audit_access_period_change(), private.validate_trainer_student_roles(), private.audit_trainer_student_change() from public;
grant execute on function private.can_read_student_access(uuid, uuid), private.can_manage_student_access(uuid, uuid) to authenticated;

alter table public.access_periods enable row level security;

create policy "read own or assigned student access periods" on public.access_periods
  for select to authenticated
  using (private.can_read_student_access(organization_id, student_id));
create policy "staff create assigned student access periods" on public.access_periods
  for insert to authenticated
  with check (
    private.can_manage_student_access(organization_id, student_id)
    and created_by = (select auth.uid())
    and updated_by = (select auth.uid())
  );
create policy "staff update assigned student access periods" on public.access_periods
  for update to authenticated
  using (private.can_manage_student_access(organization_id, student_id))
  with check (
    private.can_manage_student_access(organization_id, student_id)
    and updated_by = (select auth.uid())
  );

grant select, insert, update on public.access_periods to authenticated;

-- Future protected content must use this database authorization helper rather
-- than trusting a UI status. Expired dates and explicit blocks both deny access.
create or replace function private.has_active_student_access(
  target_organization uuid,
  target_student uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select private.can_read_student_access(target_organization, target_student)
  and exists (
    select 1 from public.access_periods ap
    where ap.organization_id = target_organization
      and ap.student_id = target_student
      and ap.status = 'active'::public.access_period_status
      and ap.starts_at <= now()
      and (ap.ends_at is null or ap.ends_at >= now())
  )
  and not exists (
    select 1 from public.access_periods ap
    where ap.organization_id = target_organization
      and ap.student_id = target_student
      and ap.status = 'blocked'::public.access_period_status
      and ap.starts_at <= now()
      and (ap.ends_at is null or ap.ends_at >= now())
  );
$$;

revoke all on function private.has_active_student_access(uuid, uuid) from public;
grant execute on function private.has_active_student_access(uuid, uuid) to authenticated;


-- 20261026182331 sprint_2_current_access
-- The most recently changed effective period is the student's current manual access state.
-- History remains in access_periods and every status update remains audited by the existing trigger.
create index access_periods_current_state_idx
  on public.access_periods (organization_id, student_id, updated_at desc);

create or replace function private.has_active_student_access(
  target_organization uuid,
  target_student uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select private.can_read_student_access(target_organization, target_student)
    and coalesce((
      select ap.status = 'active'::public.access_period_status
      from public.access_periods ap
      where ap.organization_id = target_organization
        and ap.student_id = target_student
        and ap.starts_at <= now()
        and (ap.ends_at is null or ap.ends_at >= now())
      order by ap.updated_at desc, ap.created_at desc
      limit 1
    ), false);
$$;

revoke all on function private.has_active_student_access(uuid, uuid) from public;
grant execute on function private.has_active_student_access(uuid, uuid) to authenticated;


-- 20261026182911 sprint_2_owner_student_profile_updates
-- Owners may correct the registered name of student profiles in their organization.
drop policy "update own profile" on public.profiles;
create policy "update own or owner-managed student profile" on public.profiles
  for update to authenticated
  using (
    id = (select auth.uid())
    or exists (
      select 1 from public.organization_members student_member
      where student_member.profile_id = profiles.id
        and student_member.role = 'student'::public.member_role
        and student_member.archived_at is null
        and private.is_org_owner(student_member.organization_id)
    )
  )
  with check (
    id = (select auth.uid())
    or exists (
      select 1 from public.organization_members student_member
      where student_member.profile_id = profiles.id
        and student_member.role = 'student'::public.member_role
        and student_member.archived_at is null
        and private.is_org_owner(student_member.organization_id)
    )
  );

create or replace function private.audit_owner_student_profile_change()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  target_organization uuid;
begin
  select om.organization_id into target_organization
  from public.organization_members om
  where om.profile_id = new.id
    and om.role = 'student'::public.member_role
    and om.archived_at is null
    and private.is_org_owner(om.organization_id)
  limit 1;

  if target_organization is not null and new.id <> (select auth.uid()) then
    insert into public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, metadata)
    values (target_organization, auth.uid(), 'student_profile.updated', 'profile', new.id, jsonb_build_object('full_name_changed', new.full_name is distinct from old.full_name));
  end if;
  return new;
end;
$$;

create trigger profiles_owner_student_audit after update on public.profiles
  for each row execute function private.audit_owner_student_profile_change();

revoke all on function private.audit_owner_student_profile_change() from public;


-- 20261026192430 sprint_3_onboarding_anamnesis
-- Sprint 3: recoverable onboarding and versioned, privacy-minimised anamnesis.
-- Health-answer values only live in anamnesis_answers and never in audit metadata.
create type public.onboarding_path as enum ('tour', 'anamnesis');
create type public.form_template_status as enum ('draft', 'published', 'archived');
create type public.form_question_type as enum ('text', 'number', 'single_choice', 'multiple_choice', 'boolean');
create type public.anamnesis_submission_status as enum ('draft', 'submitted');

create table public.onboarding_progress (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.profiles(id),
  selected_path public.onboarding_path,
  tour_completed_at timestamptz,
  anamnesis_started_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, student_id)
);

create table public.form_templates (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  kind text not null default 'anamnesis' check (kind = 'anamnesis'),
  title text not null check (char_length(title) between 2 and 160),
  version integer not null check (version > 0),
  status public.form_template_status not null default 'draft',
  is_temporary boolean not null default true,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  published_at timestamptz,
  unique (organization_id, kind, version)
);

create table public.form_questions (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.form_templates(id) on delete restrict,
  position integer not null check (position > 0),
  prompt text not null check (char_length(prompt) between 1 and 1000),
  question_type public.form_question_type not null,
  required boolean not null default false,
  options jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique (template_id, position),
  check (jsonb_typeof(options) = 'array'),
  check ((question_type in ('single_choice'::public.form_question_type, 'multiple_choice'::public.form_question_type) and jsonb_array_length(options) > 0) or (question_type not in ('single_choice'::public.form_question_type, 'multiple_choice'::public.form_question_type) and jsonb_array_length(options) = 0))
);

create table public.anamnesis_submissions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id),
  student_id uuid not null references public.profiles(id),
  template_id uuid not null references public.form_templates(id) on delete restrict,
  status public.anamnesis_submission_status not null default 'draft',
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (student_id, template_id),
  check ((status = 'draft'::public.anamnesis_submission_status and submitted_at is null) or (status = 'submitted'::public.anamnesis_submission_status and submitted_at is not null))
);

create table public.anamnesis_answers (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.anamnesis_submissions(id) on delete restrict,
  question_id uuid not null references public.form_questions(id) on delete restrict,
  response jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (submission_id, question_id)
);

create index form_templates_published_idx on public.form_templates (organization_id, kind, published_at desc) where status = 'published';
create index anamnesis_submissions_student_idx on public.anamnesis_submissions (organization_id, student_id, updated_at desc);
create index anamnesis_answers_submission_idx on public.anamnesis_answers (submission_id);

create or replace function private.validate_anamnesis_submission()
returns trigger language plpgsql security definer set search_path = '' as $$
declare template_org uuid; template_status public.form_template_status;
begin
  select organization_id, status into template_org, template_status from public.form_templates where id = new.template_id;
  if template_org is distinct from new.organization_id or template_status is distinct from 'published'::public.form_template_status then
    raise exception 'anamnesis submission requires a published template in the same organization';
  end if;
  if private.member_role_for(new.organization_id, new.student_id) is distinct from 'student'::public.member_role then
    raise exception 'anamnesis submission requires an active student member';
  end if;
  if tg_op = 'UPDATE' and (new.organization_id is distinct from old.organization_id or new.student_id is distinct from old.student_id or new.template_id is distinct from old.template_id or (old.status = 'submitted'::public.anamnesis_submission_status and new.status is distinct from old.status)) then
    raise exception 'submitted anamnesis identity and state are immutable';
  end if;
  if new.status = 'submitted'::public.anamnesis_submission_status and not exists (
    select 1 from public.form_questions q
    where q.template_id = new.template_id and q.required
      and not exists (select 1 from public.anamnesis_answers a where a.submission_id = new.id and a.question_id = q.id)
  ) then
    null;
  elsif new.status = 'submitted'::public.anamnesis_submission_status then
    raise exception 'all required anamnesis answers must be supplied before submission';
  end if;
  return new;
end; $$;

create or replace function private.validate_anamnesis_answer()
returns trigger language plpgsql security definer set search_path = '' as $$
declare question public.form_questions%rowtype; submission public.anamnesis_submissions%rowtype; value text;
begin
  select * into question from public.form_questions where id = new.question_id;
  select * into submission from public.anamnesis_submissions where id = new.submission_id;
  if question.template_id is distinct from submission.template_id then raise exception 'answer question must belong to submission template'; end if;
  if submission.status = 'submitted'::public.anamnesis_submission_status then raise exception 'submitted anamnesis answers are immutable'; end if;
  if question.question_type = 'text'::public.form_question_type and jsonb_typeof(new.response) <> 'string' then raise exception 'text response must be a JSON string'; end if;
  if question.question_type = 'number'::public.form_question_type and jsonb_typeof(new.response) <> 'number' then raise exception 'number response must be a JSON number'; end if;
  if question.question_type = 'boolean'::public.form_question_type and jsonb_typeof(new.response) <> 'boolean' then raise exception 'boolean response must be a JSON boolean'; end if;
  if question.question_type = 'single_choice'::public.form_question_type then
    if jsonb_typeof(new.response) <> 'string' or not question.options ? (new.response #>> '{}') then raise exception 'single choice response must be one configured option'; end if;
  end if;
  if question.question_type = 'multiple_choice'::public.form_question_type then
    if jsonb_typeof(new.response) <> 'array' or exists (select 1 from jsonb_array_elements_text(new.response) item where not question.options ? item) then raise exception 'multiple choice response must contain only configured options'; end if;
  end if;
  return new;
end; $$;

create or replace function private.prevent_published_template_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'published'::public.form_template_status and (new.title is distinct from old.title or new.version is distinct from old.version or new.is_temporary is distinct from old.is_temporary) then raise exception 'published templates are immutable; create a new version'; end if;
  if old.status = 'published'::public.form_template_status and new.status = 'draft'::public.form_template_status then raise exception 'published templates cannot return to draft'; end if;
  if new.status = 'published'::public.form_template_status and not exists (select 1 from public.form_questions q where q.template_id = new.id) then raise exception 'published templates require at least one question'; end if;
  if new.status = 'published'::public.form_template_status and new.published_at is null then new.published_at = now(); end if;
  return new;
end; $$;

create or replace function private.prevent_published_question_change()
returns trigger language plpgsql security definer set search_path = '' as $$
declare target_template uuid;
begin
  target_template := case when tg_op = 'DELETE' then old.template_id else new.template_id end;
  if exists (select 1 from public.form_templates t where t.id = target_template and t.status = 'published'::public.form_template_status) then raise exception 'published template questions are immutable'; end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end; $$;

create or replace function private.audit_anamnesis_submission_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, metadata)
  values (new.organization_id, auth.uid(), case when tg_op = 'INSERT' then 'anamnesis_submission.created' when new.status = 'submitted'::public.anamnesis_submission_status and old.status = 'draft'::public.anamnesis_submission_status then 'anamnesis_submission.submitted' else 'anamnesis_submission.updated' end, 'anamnesis_submission', new.id, jsonb_build_object('student_id', new.student_id, 'template_id', new.template_id, 'status', new.status));
  return new;
end; $$;

create trigger onboarding_progress_updated_at before update on public.onboarding_progress for each row execute function private.set_updated_at();
create trigger anamnesis_submissions_validate before insert or update on public.anamnesis_submissions for each row execute function private.validate_anamnesis_submission();
create trigger anamnesis_submissions_updated_at before update on public.anamnesis_submissions for each row execute function private.set_updated_at();
create trigger anamnesis_submissions_audit after insert or update on public.anamnesis_submissions for each row execute function private.audit_anamnesis_submission_change();
create trigger anamnesis_answers_validate before insert or update on public.anamnesis_answers for each row execute function private.validate_anamnesis_answer();
create trigger anamnesis_answers_updated_at before update on public.anamnesis_answers for each row execute function private.set_updated_at();
create trigger form_templates_immutable before update on public.form_templates for each row execute function private.prevent_published_template_change();
create trigger form_questions_immutable before insert or update or delete on public.form_questions for each row execute function private.prevent_published_question_change();

create or replace function public.get_anamnesis_owner_summary(target_organization uuid)
returns table (submission_id uuid, student_id uuid, student_name text, title text, version integer, is_temporary boolean, status public.anamnesis_submission_status, submitted_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_org_owner(target_organization) then raise exception 'not authorized'; end if;
  return query select s.id, s.student_id, p.full_name, t.title, t.version, t.is_temporary, s.status, s.submitted_at from public.anamnesis_submissions s join public.profiles p on p.id = s.student_id join public.form_templates t on t.id = s.template_id where s.organization_id = target_organization order by s.updated_at desc;
end; $$;

create or replace function public.get_anamnesis_submission_for_owner(target_submission uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb; org uuid;
begin
  select organization_id into org from public.anamnesis_submissions where id = target_submission;
  if org is null or not private.is_org_owner(org) then raise exception 'not authorized'; end if;
  select jsonb_build_object('id', s.id, 'student_id', s.student_id, 'student_name', p.full_name, 'title', t.title, 'version', t.version, 'is_temporary', t.is_temporary, 'status', s.status, 'submitted_at', s.submitted_at, 'answers', coalesce(jsonb_agg(jsonb_build_object('question_id', q.id, 'prompt', q.prompt, 'question_type', q.question_type, 'response', a.response) order by q.position) filter (where a.id is not null), '[]'::jsonb)) into result from public.anamnesis_submissions s join public.profiles p on p.id = s.student_id join public.form_templates t on t.id = s.template_id left join public.anamnesis_answers a on a.submission_id = s.id left join public.form_questions q on q.id = a.question_id where s.id = target_submission group by s.id, p.full_name, t.id;
  insert into public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, metadata) values (org, auth.uid(), 'anamnesis_submission.viewed', 'anamnesis_submission', target_submission, '{}'::jsonb);
  return result;
end; $$;

revoke all on function private.validate_anamnesis_submission(), private.validate_anamnesis_answer(), private.prevent_published_template_change(), private.prevent_published_question_change(), private.audit_anamnesis_submission_change() from public;
revoke all on function public.get_anamnesis_owner_summary(uuid), public.get_anamnesis_submission_for_owner(uuid) from public;
grant execute on function public.get_anamnesis_owner_summary(uuid), public.get_anamnesis_submission_for_owner(uuid) to authenticated;

alter table public.onboarding_progress enable row level security;
alter table public.form_templates enable row level security;
alter table public.form_questions enable row level security;
alter table public.anamnesis_submissions enable row level security;
alter table public.anamnesis_answers enable row level security;

create policy "students manage own active onboarding" on public.onboarding_progress for all to authenticated using (student_id = (select auth.uid()) and private.has_active_student_access(organization_id, student_id)) with check (student_id = (select auth.uid()) and private.has_active_student_access(organization_id, student_id));
create policy "owners read onboarding progress" on public.onboarding_progress for select to authenticated using (private.is_org_owner(organization_id));
create policy "members read published active templates" on public.form_templates for select to authenticated using (private.is_org_owner(organization_id) or (status = 'published'::public.form_template_status and private.has_active_student_access(organization_id, (select auth.uid()))));
create policy "owners manage templates" on public.form_templates for all to authenticated using (private.is_org_owner(organization_id)) with check (private.is_org_owner(organization_id));
create policy "members read published template questions" on public.form_questions for select to authenticated using (exists (select 1 from public.form_templates t where t.id = template_id and (private.is_org_owner(t.organization_id) or (t.status = 'published'::public.form_template_status and private.has_active_student_access(t.organization_id, (select auth.uid()))))));
create policy "owners manage questions" on public.form_questions for all to authenticated using (exists (select 1 from public.form_templates t where t.id = template_id and private.is_org_owner(t.organization_id))) with check (exists (select 1 from public.form_templates t where t.id = template_id and private.is_org_owner(t.organization_id)));
create policy "students manage own active submissions" on public.anamnesis_submissions for all to authenticated using (student_id = (select auth.uid()) and private.has_active_student_access(organization_id, student_id)) with check (student_id = (select auth.uid()) and private.has_active_student_access(organization_id, student_id));
create policy "students manage own active answers" on public.anamnesis_answers for all to authenticated using (exists (select 1 from public.anamnesis_submissions s where s.id = submission_id and s.student_id = (select auth.uid()) and private.has_active_student_access(s.organization_id, s.student_id))) with check (exists (select 1 from public.anamnesis_submissions s where s.id = submission_id and s.student_id = (select auth.uid()) and private.has_active_student_access(s.organization_id, s.student_id)));

grant select, insert, update on public.onboarding_progress, public.form_templates, public.form_questions, public.anamnesis_submissions, public.anamnesis_answers to authenticated;


-- 20261026192440 sprint_3_trainer_anamnesis_access
-- Sprint 3 follow-up: trainers may consult anamneses only for active students
-- in their own, non-archived portfolio. Direct tables remain unavailable.
create or replace function public.get_anamnesis_trainer_summary(target_organization uuid)
returns table (submission_id uuid, student_id uuid, student_name text, title text, version integer, is_temporary boolean, status public.anamnesis_submission_status, submitted_at timestamptz)
language plpgsql security definer set search_path = '' as $$
begin
  if private.member_role_for(target_organization, (select auth.uid())) is distinct from 'trainer'::public.member_role then
    raise exception 'not authorized';
  end if;
  return query
    select s.id, s.student_id, p.full_name, t.title, t.version, t.is_temporary, s.status, s.submitted_at
    from public.anamnesis_submissions s
    join public.profiles p on p.id = s.student_id
    join public.form_templates t on t.id = s.template_id
    join public.trainer_students ts on ts.organization_id = s.organization_id
      and ts.student_id = s.student_id
      and ts.trainer_id = (select auth.uid())
      and ts.archived_at is null
    where s.organization_id = target_organization
      and private.has_active_student_access(s.organization_id, s.student_id)
    order by s.updated_at desc;
end; $$;

create or replace function public.get_anamnesis_submission_for_trainer(target_submission uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb; org uuid; student uuid;
begin
  select organization_id, student_id into org, student from public.anamnesis_submissions where id = target_submission;
  if org is null
    or private.member_role_for(org, (select auth.uid())) is distinct from 'trainer'::public.member_role
    or not exists (
      select 1 from public.trainer_students ts
      where ts.organization_id = org and ts.student_id = student and ts.trainer_id = (select auth.uid()) and ts.archived_at is null
    )
    or not private.has_active_student_access(org, student) then
    raise exception 'not authorized';
  end if;
  select jsonb_build_object(
    'id', s.id, 'student_id', s.student_id, 'student_name', p.full_name,
    'title', t.title, 'version', t.version, 'is_temporary', t.is_temporary,
    'status', s.status, 'submitted_at', s.submitted_at,
    'answers', coalesce(jsonb_agg(jsonb_build_object('question_id', q.id, 'prompt', q.prompt, 'question_type', q.question_type, 'response', a.response) order by q.position) filter (where a.id is not null), '[]'::jsonb)
  ) into result
  from public.anamnesis_submissions s
  join public.profiles p on p.id = s.student_id
  join public.form_templates t on t.id = s.template_id
  left join public.anamnesis_answers a on a.submission_id = s.id
  left join public.form_questions q on q.id = a.question_id
  where s.id = target_submission
  group by s.id, p.full_name, t.id;
  insert into public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, metadata)
  values (org, auth.uid(), 'anamnesis_submission.viewed', 'anamnesis_submission', target_submission, jsonb_build_object('viewer_role', 'trainer'));
  return result;
end; $$;

revoke all on function public.get_anamnesis_trainer_summary(uuid), public.get_anamnesis_submission_for_trainer(uuid) from public;
grant execute on function public.get_anamnesis_trainer_summary(uuid), public.get_anamnesis_submission_for_trainer(uuid) to authenticated;


-- 20261026192649 sprint_3_revoke_anon_anamnesis_rpcs
-- Supabase grants EXECUTE to anon by default for public-schema functions.
-- These health-data RPCs must only be callable with an authenticated session.
revoke execute on function public.get_anamnesis_owner_summary(uuid) from anon;
revoke execute on function public.get_anamnesis_submission_for_owner(uuid) from anon;
revoke execute on function public.get_anamnesis_trainer_summary(uuid) from anon;
revoke execute on function public.get_anamnesis_submission_for_trainer(uuid) from anon;

grant execute on function public.get_anamnesis_owner_summary(uuid), public.get_anamnesis_submission_for_owner(uuid), public.get_anamnesis_trainer_summary(uuid), public.get_anamnesis_submission_for_trainer(uuid) to authenticated;


-- 20261026202051 sprint_3_form_draft_editing
-- Only owner-editable draft questions can be replaced; published versions and
-- their associated submissions remain immutable.
grant delete on public.form_questions to authenticated;


-- 20261026221530 sprint_3_form_removal
create or replace function private.prevent_non_draft_template_delete()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status <> 'draft'::public.form_template_status then
    raise exception 'only draft templates can be deleted; archive published templates instead';
  end if;
  return old;
end; $$;

drop trigger if exists form_templates_draft_delete_only on public.form_templates;
create trigger form_templates_draft_delete_only
before delete on public.form_templates
for each row execute function private.prevent_non_draft_template_delete();

alter table public.form_questions drop constraint form_questions_template_id_fkey;
alter table public.form_questions
  add constraint form_questions_template_id_fkey
  foreign key (template_id) references public.form_templates(id) on delete cascade;

grant delete on public.form_templates to authenticated;
revoke all on function private.prevent_non_draft_template_delete() from public;
