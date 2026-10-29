-- Sprint 2: keep authorization in membership/RLS and protect clinical history.
alter table public.onboarding_progress add column tour_step integer not null default 0 check (tour_step between 0 and 3);

create or replace function private.is_active_student(org uuid, student uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select private.has_role(org, array['student']::public.member_role[]) and student = auth.uid()
   and private.has_active_student_access(org, student);
$$;

-- Published content is frozen; archiving only changes its state and timestamp.
create or replace function private.prevent_published_form_mutation() returns trigger language plpgsql set search_path = '' as $$
begin
 if old.state = 'archived' then raise exception 'archived forms are immutable'; end if;
 if old.state = 'published' then
   if tg_op = 'DELETE' then raise exception 'published forms cannot be deleted'; end if;
   if new.state <> 'archived' or (to_jsonb(new) - array['state','archived_at','updated_at','updated_by']) is distinct from (to_jsonb(old) - array['state','archived_at','updated_at','updated_by']) or new.archived_at is null then
     raise exception 'published forms are immutable';
   end if;
 end if;
 if tg_op = 'DELETE' then return old; end if;
 if old.state = 'draft' and new.state = 'archived' then raise exception 'only published forms can be archived'; end if;
 if old.state = 'draft' and new.state = 'published' then
   if not exists(select 1 from public.form_questions where form_template_id = old.id) then raise exception 'form needs questions'; end if;
   new.published_at := now();
 end if;
 return new;
end $$;

create function private.guard_form_insert() returns trigger language plpgsql set search_path = '' as $$
begin
 if new.state <> 'draft' or new.published_at is not null or new.archived_at is not null then raise exception 'forms must start as drafts'; end if;
 return new;
end $$;
create trigger guard_form_insert before insert on public.form_templates for each row execute function private.guard_form_insert();

create function private.guard_question() returns trigger language plpgsql set search_path = '' as $$
declare parent_state public.form_state;
begin
 select state into parent_state from public.form_templates where id = coalesce(old.form_template_id, new.form_template_id) for update;
 if parent_state is null and tg_op = 'DELETE' then return old; end if;
 if parent_state is distinct from 'draft' then raise exception 'questions of published forms are immutable'; end if;
 if tg_op = 'UPDATE' and new.form_template_id <> old.form_template_id then raise exception 'question cannot change form'; end if;
 if tg_op = 'DELETE' then return old; end if;
 if length(trim(new.prompt)) = 0 or jsonb_typeof(new.options) <> 'array' then raise exception 'invalid question'; end if;
 if new.kind in ('single_choice','multiple_choice') and (jsonb_array_length(new.options) < 2 or exists(select 1 from jsonb_array_elements(new.options) x where jsonb_typeof(x) <> 'string' or length(trim(x #>> '{}')) = 0) or (select count(distinct x) from jsonb_array_elements(new.options) x) <> jsonb_array_length(new.options)) then raise exception 'invalid options'; end if;
 return new;
end $$;
create trigger guard_question before insert or update or delete on public.form_questions for each row execute function private.guard_question();

create function private.guard_submission() returns trigger language plpgsql set search_path = '' as $$
begin
 if tg_op = 'DELETE' then raise exception 'submissions cannot be deleted'; end if;
 if tg_op = 'UPDATE' and (new.organization_id, new.form_template_id, new.student_id) is distinct from (old.organization_id, old.form_template_id, old.student_id) then raise exception 'submission identity is immutable'; end if;
 if not exists(select 1 from public.form_templates f where f.id = new.form_template_id and f.organization_id = new.organization_id and (f.state = 'published' or (tg_op = 'UPDATE' and f.state = 'archived'))) then raise exception 'invalid form'; end if;
 if new.status = 'submitted' and (tg_op = 'INSERT' or old.status = 'draft') then
   if exists(select 1 from public.form_questions q left join public.anamnesis_answers a on a.question_id = q.id and a.submission_id = new.id where q.form_template_id = new.form_template_id and q.required and (a.id is null or a.answer = 'null'::jsonb or (jsonb_typeof(a.answer) = 'string' and length(trim(a.answer #>> '{}')) = 0) or a.answer = '[]'::jsonb)) then raise exception 'required answers missing'; end if;
   new.submitted_at := now();
 end if;
 return new;
end $$;
create trigger guard_submission before insert or update or delete on public.anamnesis_submissions for each row execute function private.guard_submission();

create function private.guard_answer() returns trigger language plpgsql set search_path = '' as $$
declare s public.anamnesis_submissions%rowtype; q public.form_questions%rowtype;
begin
 select * into s from public.anamnesis_submissions where id = coalesce(old.submission_id, new.submission_id) for update;
 if s.status is distinct from 'draft' then raise exception 'submitted answers are immutable'; end if;
 if tg_op = 'DELETE' then return old; end if;
 if tg_op = 'UPDATE' and (new.submission_id, new.question_id) is distinct from (old.submission_id, old.question_id) then raise exception 'answer identity is immutable'; end if;
 select * into q from public.form_questions where id = new.question_id and form_template_id = s.form_template_id;
 if not found then raise exception 'question does not belong to form'; end if;
 if new.answer <> 'null'::jsonb and not (case q.kind
   when 'text' then jsonb_typeof(new.answer) = 'string'
   when 'number' then jsonb_typeof(new.answer) = 'number'
   when 'boolean' then jsonb_typeof(new.answer) = 'boolean'
   when 'single_choice' then jsonb_typeof(new.answer) = 'string' and q.options ? (new.answer #>> '{}')
   when 'multiple_choice' then case when jsonb_typeof(new.answer) = 'array' then not exists(select 1 from jsonb_array_elements(new.answer) v where jsonb_typeof(v) <> 'string' or not (q.options ? (v #>> '{}'))) and (select count(distinct v) from jsonb_array_elements(new.answer) v) = jsonb_array_length(new.answer) else false end
 end) then raise exception 'invalid answer'; end if;
 return new;
end $$;
create trigger guard_answer before insert or update or delete on public.anamnesis_answers for each row execute function private.guard_answer();

drop policy "progress_student" on public.onboarding_progress;
create policy progress_student on public.onboarding_progress for all to authenticated using (private.is_active_student(organization_id, student_id)) with check (private.is_active_student(organization_id, student_id));
drop policy "forms_student_read_published" on public.form_templates;
create policy forms_student_read_published on public.form_templates for select to authenticated using (state = 'published' and private.is_active_student(organization_id, auth.uid()));
drop policy "questions_student_read_published" on public.form_questions;
create policy questions_student_read_published on public.form_questions for select to authenticated using (exists(select 1 from public.form_templates f where f.id = form_template_id and f.state = 'published' and private.is_active_student(f.organization_id, auth.uid())));
drop policy "submissions_student_only" on public.anamnesis_submissions;
create policy submissions_student_only on public.anamnesis_submissions for all to authenticated using (private.is_active_student(organization_id, student_id)) with check (private.is_active_student(organization_id, student_id));
drop policy "answers_student_only" on public.anamnesis_answers;
create policy answers_student_only on public.anamnesis_answers for all to authenticated using (exists(select 1 from public.anamnesis_submissions s where s.id = submission_id and private.is_active_student(s.organization_id, s.student_id))) with check (exists(select 1 from public.anamnesis_submissions s where s.id = submission_id and s.status = 'draft' and private.is_active_student(s.organization_id, s.student_id)));
