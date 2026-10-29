-- Additive reconciliation for the pre-existing Padua Training test database.
-- Existing migrations and data are intentionally retained.
alter table public.onboarding_progress add column tour_step integer not null default 0 check (tour_step between 0 and 3);
alter table public.form_templates add column description text;

create or replace function private.has_active_student_access(target_organization uuid, target_student uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select private.member_role_for(target_organization, target_student) = 'student'::public.member_role
   and private.can_read_student_access(target_organization, target_student)
   and coalesce((select ap.status = 'active'::public.access_period_status
     from public.access_periods ap where ap.organization_id = target_organization and ap.student_id = target_student
       and ap.starts_at <= now() and (ap.ends_at is null or ap.ends_at >= now())
     order by ap.updated_at desc, ap.created_at desc, (ap.status <> 'active'::public.access_period_status) desc, ap.id desc limit 1), false);
$$;

create or replace function private.prevent_published_template_change() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 if old.status = 'archived' then raise exception 'archived templates are immutable'; end if;
 if old.status = 'published' then
   if new.status <> 'archived' or (to_jsonb(new) - 'status') is distinct from (to_jsonb(old) - 'status') then
     raise exception 'published templates are immutable; archive or create a new version';
   end if;
 elsif old.status = 'draft' and new.status = 'archived' then
   raise exception 'only published templates can be archived';
 end if;
 if new.status = 'published' and old.status = 'draft' then
   if not exists (select 1 from public.form_questions q where q.template_id = new.id) then raise exception 'published templates require at least one question'; end if;
   new.published_at := now();
 end if;
 return new;
end $$;
create function private.reconcile_template_insert_guard() returns trigger language plpgsql set search_path = '' as $$
begin
 if new.status <> 'draft' or new.published_at is not null then raise exception 'templates must start as drafts'; end if;
 return new;
end $$;
create trigger reconcile_template_insert_guard before insert on public.form_templates for each row execute function private.reconcile_template_insert_guard();

create or replace function private.prevent_published_question_change() returns trigger
language plpgsql security definer set search_path = '' as $$
declare parent_status public.form_template_status;
begin
 select status into parent_status from public.form_templates where id = case when tg_op = 'INSERT' then new.template_id else old.template_id end for update;
 if parent_status is null and tg_op = 'DELETE' then return old; end if;
 if parent_status is distinct from 'draft' then raise exception 'published and archived questions are immutable'; end if;
 if tg_op = 'UPDATE' and new.template_id is distinct from old.template_id then raise exception 'question cannot change template'; end if;
 if tg_op = 'DELETE' then return old; end if;
 if length(trim(new.prompt)) = 0 then raise exception 'question cannot be empty'; end if;
 if new.question_type in ('single_choice','multiple_choice') and (jsonb_array_length(new.options) < 2 or exists(select 1 from jsonb_array_elements(new.options) x where jsonb_typeof(x) <> 'string' or length(trim(x #>> '{}')) = 0) or (select count(distinct x) from jsonb_array_elements(new.options) x) <> jsonb_array_length(new.options)) then raise exception 'invalid options'; end if;
 return new;
end $$;

create function private.reconcile_submission_guard() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if tg_op = 'DELETE' then raise exception 'anamnesis submissions cannot be deleted'; end if;
 if tg_op = 'INSERT' and new.status <> 'draft' then raise exception 'anamnesis must start as draft'; end if;
 if tg_op = 'UPDATE' and old.status = 'submitted' then raise exception 'submitted anamnesis is immutable'; end if;
 if new.status = 'submitted' then
   if exists(select 1 from public.form_questions q left join public.anamnesis_answers a on a.question_id = q.id and a.submission_id = new.id where q.template_id = new.template_id and q.required and (a.id is null or a.response = 'null'::jsonb or (jsonb_typeof(a.response) = 'string' and length(trim(a.response #>> '{}')) = 0) or a.response = '[]'::jsonb)) then raise exception 'required answers missing'; end if;
   new.submitted_at := now();
 end if;
 return new;
end $$;
create trigger reconcile_submission_guard before insert or update or delete on public.anamnesis_submissions for each row execute function private.reconcile_submission_guard();

create function private.reconcile_answer_guard() returns trigger language plpgsql security definer set search_path = '' as $$
declare submission_status public.anamnesis_submission_status;
begin
 select status into submission_status from public.anamnesis_submissions where id = case when tg_op = 'INSERT' then new.submission_id else old.submission_id end for update;
 if submission_status is distinct from 'draft' then raise exception 'submitted answers are immutable'; end if;
 if tg_op = 'DELETE' then return old; end if;
 if tg_op = 'UPDATE' and (new.submission_id, new.question_id) is distinct from (old.submission_id, old.question_id) then raise exception 'answer identity is immutable'; end if;
 if jsonb_typeof(new.response) = 'array' and (select count(distinct x) from jsonb_array_elements(new.response) x) <> jsonb_array_length(new.response) then raise exception 'duplicate answers are invalid'; end if;
 return new;
end $$;
create trigger reconcile_answer_guard before insert or update or delete on public.anamnesis_answers for each row execute function private.reconcile_answer_guard();
-- Draft answers can be cleared; the trigger rejects deletion after submission.
grant delete on public.anamnesis_answers to authenticated;
