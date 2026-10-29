-- Padua Training foundation. This migration is additive; do not edit published history.
create extension if not exists pgcrypto;
create schema if not exists private;

create type public.member_role as enum ('owner', 'trainer', 'student');
create type public.access_status as enum ('pending', 'active', 'expired', 'blocked');
create type public.form_state as enum ('draft', 'published', 'archived');
create type public.question_kind as enum ('text', 'number', 'single_choice', 'multiple_choice', 'boolean');

create or replace function private.set_updated_at() returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = timezone('utc', now()); return new; end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create table public.organizations (
  id uuid primary key default gen_random_uuid(), name text not null, slug text not null unique,
  created_at timestamptz not null default timezone('utc', now()), updated_at timestamptz not null default timezone('utc', now()), created_by uuid references auth.users(id)
);
create table public.organization_members (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), user_id uuid not null references auth.users(id), role public.member_role not null,
  created_at timestamptz not null default timezone('utc', now()), updated_at timestamptz not null default timezone('utc', now()), created_by uuid references auth.users(id),
  unique (organization_id, user_id)
);
create table public.trainer_students (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), trainer_id uuid not null references auth.users(id), student_id uuid not null references auth.users(id),
  active boolean not null default true, created_at timestamptz not null default timezone('utc', now()), updated_at timestamptz not null default timezone('utc', now()), created_by uuid references auth.users(id),
  unique (organization_id, trainer_id, student_id), check (trainer_id <> student_id)
);
create table public.access_periods (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), student_id uuid not null references auth.users(id),
  starts_at timestamptz not null, ends_at timestamptz, status public.access_status not null default 'pending', responsible_id uuid references auth.users(id), created_by uuid references auth.users(id), updated_by uuid references auth.users(id), note text,
  created_at timestamptz not null default timezone('utc', now()), updated_at timestamptz not null default timezone('utc', now()), check (ends_at is null or ends_at > starts_at)
);
create table public.onboarding_progress (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), student_id uuid not null references auth.users(id),
  tour_completed_at timestamptz, anamnesis_started_at timestamptz, anamnesis_completed_at timestamptz, created_at timestamptz not null default timezone('utc', now()), updated_at timestamptz not null default timezone('utc', now()),
  unique (organization_id, student_id)
);
create table public.form_templates (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), title text not null, description text, state public.form_state not null default 'draft', version integer not null default 1,
  published_at timestamptz, archived_at timestamptz, source_template_id uuid references public.form_templates(id), created_by uuid references auth.users(id), updated_by uuid references auth.users(id),
  created_at timestamptz not null default timezone('utc', now()), updated_at timestamptz not null default timezone('utc', now()), unique (organization_id, title, version)
);
create table public.form_questions (
  id uuid primary key default gen_random_uuid(), form_template_id uuid not null references public.form_templates(id) on delete cascade, position integer not null, prompt text not null, kind public.question_kind not null,
  required boolean not null default false, options jsonb not null default '[]'::jsonb, created_at timestamptz not null default timezone('utc', now()), updated_at timestamptz not null default timezone('utc', now()), unique (form_template_id, position)
);
create table public.anamnesis_submissions (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), form_template_id uuid not null references public.form_templates(id), student_id uuid not null references auth.users(id),
  status text not null default 'draft' check (status in ('draft', 'submitted')), submitted_at timestamptz, created_at timestamptz not null default timezone('utc', now()), updated_at timestamptz not null default timezone('utc', now()),
  unique (form_template_id, student_id), check ((status = 'submitted') = (submitted_at is not null))
);
create table public.anamnesis_answers (
  id uuid primary key default gen_random_uuid(), submission_id uuid not null references public.anamnesis_submissions(id) on delete restrict, question_id uuid not null references public.form_questions(id), answer jsonb not null,
  created_at timestamptz not null default timezone('utc', now()), updated_at timestamptz not null default timezone('utc', now()), unique (submission_id, question_id)
);
create table public.audit_logs (
  id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id), actor_id uuid references auth.users(id), action text not null, entity_type text not null, entity_id uuid,
  metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default timezone('utc', now())
);

create index organization_members_user_org_idx on public.organization_members(user_id, organization_id);
create index trainer_students_trainer_idx on public.trainer_students(trainer_id, organization_id) where active;
create index trainer_students_student_idx on public.trainer_students(student_id, organization_id) where active;
create index access_periods_effective_idx on public.access_periods(organization_id, student_id, updated_at desc);
create index form_templates_org_state_idx on public.form_templates(organization_id, state);
create index form_questions_template_position_idx on public.form_questions(form_template_id, position);
create index submissions_student_idx on public.anamnesis_submissions(student_id, organization_id);
create index audit_logs_org_created_idx on public.audit_logs(organization_id, created_at desc);

create or replace function private.has_role(target_organization uuid, allowed_roles public.member_role[]) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.organization_members m where m.organization_id = target_organization and m.user_id = auth.uid() and m.role = any(allowed_roles));
$$;
create or replace function private.is_linked_trainer(target_organization uuid, target_student uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.trainer_students ts where ts.organization_id = target_organization and ts.trainer_id = auth.uid() and ts.student_id = target_student and ts.active);
$$;
create or replace function private.has_active_student_access(target_organization uuid, target_student uuid) returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select ap.status = 'active' and ap.starts_at <= timezone('utc', now()) and (ap.ends_at is null or ap.ends_at > timezone('utc', now())) from public.access_periods ap where ap.organization_id = target_organization and ap.student_id = target_student order by ap.updated_at desc, ap.id desc limit 1), false);
$$;

create or replace function private.prevent_published_form_mutation() returns trigger language plpgsql set search_path = '' as $$
begin
  if old.state in ('published', 'archived') then raise exception 'published and archived forms are immutable'; end if;
  return new;
end;
$$;
create or replace function private.prevent_submitted_mutation() returns trigger language plpgsql set search_path = '' as $$
begin
  if old.status = 'submitted' then raise exception 'submitted anamnesis is immutable'; end if;
  return new;
end;
$$;
create or replace function private.audit_access_period() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, metadata)
  values (coalesce(new.organization_id, old.organization_id), auth.uid(), tg_op || '.access_period', 'access_period', coalesce(new.id, old.id), jsonb_build_object('status', coalesce(new.status, old.status)));
  return coalesce(new, old);
end;
$$;

create trigger profiles_updated before update on public.profiles for each row execute function private.set_updated_at();
create trigger organizations_updated before update on public.organizations for each row execute function private.set_updated_at();
create trigger members_updated before update on public.organization_members for each row execute function private.set_updated_at();
create trigger trainer_students_updated before update on public.trainer_students for each row execute function private.set_updated_at();
create trigger access_periods_updated before update on public.access_periods for each row execute function private.set_updated_at();
create trigger progress_updated before update on public.onboarding_progress for each row execute function private.set_updated_at();
create trigger forms_updated before update on public.form_templates for each row execute function private.set_updated_at();
create trigger questions_updated before update on public.form_questions for each row execute function private.set_updated_at();
create trigger submissions_updated before update on public.anamnesis_submissions for each row execute function private.set_updated_at();
create trigger answers_updated before update on public.anamnesis_answers for each row execute function private.set_updated_at();
create trigger immutable_forms before update or delete on public.form_templates for each row execute function private.prevent_published_form_mutation();
create trigger immutable_submissions before update or delete on public.anamnesis_submissions for each row execute function private.prevent_submitted_mutation();
create trigger audit_access_periods after insert or update or delete on public.access_periods for each row execute function private.audit_access_period();

alter table public.profiles enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;
alter table public.trainer_students enable row level security;
alter table public.access_periods enable row level security;
alter table public.onboarding_progress enable row level security;
alter table public.form_templates enable row level security;
alter table public.form_questions enable row level security;
alter table public.anamnesis_submissions enable row level security;
alter table public.anamnesis_answers enable row level security;
alter table public.audit_logs enable row level security;

create policy "profiles_self" on public.profiles for all using (id = auth.uid()) with check (id = auth.uid());
create policy "organizations_member_read" on public.organizations for select using (private.has_role(id, array['owner','trainer','student']::public.member_role[]));
create policy "organizations_owner_manage" on public.organizations for update using (private.has_role(id, array['owner']::public.member_role[]));
create policy "members_self_or_owner" on public.organization_members for select using (user_id = auth.uid() or private.has_role(organization_id, array['owner']::public.member_role[]));
create policy "trainer_students_scoped_read" on public.trainer_students for select using (student_id = auth.uid() or trainer_id = auth.uid() or private.has_role(organization_id, array['owner']::public.member_role[]));
create policy "trainer_students_owner_manage" on public.trainer_students for all using (private.has_role(organization_id, array['owner']::public.member_role[])) with check (private.has_role(organization_id, array['owner']::public.member_role[]));
create policy "access_periods_scoped_read" on public.access_periods for select using (student_id = auth.uid() or private.has_role(organization_id, array['owner']::public.member_role[]) or private.is_linked_trainer(organization_id, student_id));
create policy "access_periods_owner_manage" on public.access_periods for all using (private.has_role(organization_id, array['owner']::public.member_role[])) with check (private.has_role(organization_id, array['owner']::public.member_role[]));
create policy "progress_student" on public.onboarding_progress for all using (student_id = auth.uid()) with check (student_id = auth.uid());
create policy "forms_owner_manage" on public.form_templates for all using (private.has_role(organization_id, array['owner']::public.member_role[])) with check (private.has_role(organization_id, array['owner']::public.member_role[]));
create policy "forms_student_read_published" on public.form_templates for select using (state = 'published' and private.has_active_student_access(organization_id, auth.uid()));
create policy "questions_owner_manage" on public.form_questions for all using (exists(select 1 from public.form_templates ft where ft.id = form_template_id and private.has_role(ft.organization_id, array['owner']::public.member_role[]))) with check (exists(select 1 from public.form_templates ft where ft.id = form_template_id and private.has_role(ft.organization_id, array['owner']::public.member_role[])));
create policy "questions_student_read_published" on public.form_questions for select using (exists(select 1 from public.form_templates ft where ft.id = form_template_id and ft.state = 'published' and private.has_active_student_access(ft.organization_id, auth.uid())));
create policy "submissions_student_only" on public.anamnesis_submissions for all using (student_id = auth.uid()) with check (student_id = auth.uid() and private.has_active_student_access(organization_id, auth.uid()));
create policy "answers_student_only" on public.anamnesis_answers for all using (exists(select 1 from public.anamnesis_submissions s where s.id = submission_id and s.student_id = auth.uid())) with check (exists(select 1 from public.anamnesis_submissions s where s.id = submission_id and s.student_id = auth.uid() and s.status = 'draft'));
create policy "audit_owner_read" on public.audit_logs for select using (private.has_role(organization_id, array['owner']::public.member_role[]));

create or replace function public.review_anamnesis_submission(target_submission uuid) returns jsonb language plpgsql security definer set search_path = '' as $$
declare result jsonb; target_org uuid; target_student uuid;
begin
  select organization_id, student_id into target_org, target_student from public.anamnesis_submissions where id = target_submission;
  if target_org is null or not (private.has_role(target_org, array['owner']::public.member_role[]) or (private.has_role(target_org, array['trainer']::public.member_role[]) and private.is_linked_trainer(target_org, target_student) and private.has_active_student_access(target_org, target_student))) then raise exception 'not authorized'; end if;
  select jsonb_build_object('id', s.id, 'student_id', s.student_id, 'status', s.status, 'submitted_at', s.submitted_at, 'answers', coalesce(jsonb_agg(jsonb_build_object('question_id', a.question_id, 'answer', a.answer)) filter (where a.id is not null), '[]'::jsonb)) into result from public.anamnesis_submissions s left join public.anamnesis_answers a on a.submission_id = s.id where s.id = target_submission group by s.id;
  insert into public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, metadata) values (target_org, auth.uid(), 'anamnesis.reviewed', 'anamnesis_submission', target_submission, jsonb_build_object('purpose', 'authorized_review'));
  return result;
end;
$$;
revoke all on function public.review_anamnesis_submission(uuid) from public;
grant execute on function public.review_anamnesis_submission(uuid) to authenticated;

-- Table privileges are deliberately narrow; RLS remains the authorization boundary.
grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
grant select on public.organizations, public.organization_members, public.trainer_students, public.access_periods, public.audit_logs to authenticated;
grant insert, update on public.trainer_students, public.access_periods to authenticated;
grant select, insert, update, delete on public.onboarding_progress, public.form_templates, public.form_questions, public.anamnesis_submissions, public.anamnesis_answers to authenticated;
