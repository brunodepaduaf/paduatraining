\set ON_ERROR_STOP on
begin;

create schema auth;
create table auth.users (id uuid primary key);
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create role authenticated nologin;

\ir ../migrations/202610290001_foundation.sql

insert into auth.users values
 ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000003'), ('00000000-0000-0000-0000-000000000004'),
 ('00000000-0000-0000-0000-000000000005');
insert into public.organizations(id, name, slug) values
 ('10000000-0000-0000-0000-000000000001', 'Org A', 'org-a'), ('20000000-0000-0000-0000-000000000001', 'Org B', 'org-b');
insert into public.organization_members(organization_id, user_id, role) values
 ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'owner'),
 ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'trainer'),
 ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'student'),
 ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 'owner'),
 ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', 'student');
insert into public.trainer_students(organization_id, trainer_id, student_id) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003');
insert into public.access_periods(organization_id, student_id, starts_at, status) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', now() - interval '1 day', 'active');
insert into public.form_templates(id, organization_id, title, state) values ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Anamnese provisória', 'published');
insert into public.form_questions(id, form_template_id, position, prompt, kind) values ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 1, 'Como está se sentindo?', 'text');
insert into public.anamnesis_submissions(id, organization_id, form_template_id, student_id, status) values ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 'draft');
insert into public.anamnesis_answers(submission_id, question_id, answer) values ('50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', '"sintético"');

\ir ../migrations/20261029015804_onboarding_anamnesis.sql

set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin
  if (select count(*) from public.form_templates) <> 1 then raise exception 'active student cannot read published form'; end if;
  if (select count(*) from public.anamnesis_answers) <> 1 then raise exception 'student cannot read own answers'; end if;
  if (select count(*) from public.audit_logs) <> 0 then raise exception 'student read audit logs'; end if;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$ begin
  if (select count(*) from public.anamnesis_submissions) <> 0 then raise exception 'trainer has direct clinical read'; end if;
  if (select public.review_anamnesis_submission('50000000-0000-0000-0000-000000000001') is not null) is not true then raise exception 'linked trainer cannot use audited RPC'; end if;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000004';
do $$ begin
  if (select count(*) from public.organizations) <> 1 then raise exception 'cross-organization read'; end if;
  if (select count(*) from public.form_templates) <> 0 then raise exception 'cross-organization form read'; end if;
  begin perform public.review_anamnesis_submission('50000000-0000-0000-0000-000000000001'); raise exception 'cross-organization review succeeded'; exception when raise_exception then if sqlerrm = 'cross-organization review succeeded' then raise; end if; end;
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin
  if (select count(*) from public.anamnesis_submissions) <> 0 then raise exception 'owner has direct clinical read'; end if;
  if (select public.review_anamnesis_submission('50000000-0000-0000-0000-000000000001') is not null) is not true then raise exception 'owner cannot use audited RPC'; end if;
end $$;
-- Owner cannot mutate published questions or delete published history.
do $$ declare rejected boolean := false; begin
  begin update public.form_questions set prompt = 'alterada' where id = '40000000-0000-0000-0000-000000000001'; exception when others then rejected := true; end;
  if not rejected then raise exception 'published question was mutable'; end if;
  rejected := false;
  begin delete from public.form_templates where id = '30000000-0000-0000-0000-000000000001'; exception when others then rejected := true; end;
  if not rejected then raise exception 'published form was deleted'; end if;
end $$;
-- Draft lifecycle, including cascade delete, stays available to the owner.
insert into public.form_templates(id, organization_id, title) values ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Rascunho sintético');
insert into public.form_questions(form_template_id, position, prompt, kind) values ('30000000-0000-0000-0000-000000000002', 1, 'Pergunta sintética', 'text');
delete from public.form_templates where id = '30000000-0000-0000-0000-000000000002';
-- A new version requires valid questions and validates required answers at submission.
insert into public.form_templates(id, organization_id, title) values ('30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'Nova versão sintética');
insert into public.form_questions(id, form_template_id, position, prompt, kind, required) values ('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000003', 1, 'Pergunta obrigatória', 'boolean', true);
update public.form_templates set state = 'published' where id = '30000000-0000-0000-0000-000000000003';
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
insert into public.anamnesis_submissions(id, organization_id, form_template_id, student_id) values ('50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003');
do $$ declare rejected boolean := false; begin
  begin update public.anamnesis_submissions set status = 'submitted', submitted_at = now() where id = '50000000-0000-0000-0000-000000000003'; exception when others then rejected := true; end;
  if not rejected then raise exception 'submission accepted without required answer'; end if;
  rejected := false;
  begin insert into public.anamnesis_answers(submission_id, question_id, answer) values ('50000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000001', '"wrong form"'); exception when others then rejected := true; end;
  if not rejected then raise exception 'answer accepted for another form'; end if;
  rejected := false;
  begin insert into public.anamnesis_answers(submission_id, question_id, answer) values ('50000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000003', '"not boolean"'); exception when others then rejected := true; end;
  if not rejected then raise exception 'invalid answer accepted'; end if;
end $$;
insert into public.anamnesis_answers(submission_id, question_id, answer) values ('50000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000003', 'false');
update public.anamnesis_submissions set status = 'submitted', submitted_at = now() where id = '50000000-0000-0000-0000-000000000003';
-- Student can submit, but cannot mutate or remove submitted answers.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
update public.anamnesis_submissions set status = 'submitted', submitted_at = now() where id = '50000000-0000-0000-0000-000000000001';
do $$ declare rejected boolean := false; begin
  begin update public.anamnesis_answers set answer = '"alterada"' where submission_id = '50000000-0000-0000-0000-000000000001'; exception when others then rejected := true; end;
  if not rejected then raise exception 'submitted answer was mutable'; end if;
  rejected := false;
  begin delete from public.anamnesis_answers where submission_id = '50000000-0000-0000-0000-000000000001'; exception when others then rejected := true; end;
  if not rejected then raise exception 'submitted answer was deleted'; end if;
end $$;
-- Archiving is the only allowed mutation of a published version.
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
update public.form_templates set state = 'archived', archived_at = now() where id = '30000000-0000-0000-0000-000000000001';
do $$ declare rejected boolean := false; begin
  begin update public.form_templates set title = 'alterado' where id = '30000000-0000-0000-0000-000000000001'; exception when others then rejected := true; end;
  if not rejected then raise exception 'archived form was mutable'; end if;
end $$;
-- Revocation immediately hides even the student's own clinical rows.
reset role;
insert into public.access_periods(organization_id, student_id, starts_at, status, updated_at) values ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', now() - interval '1 day', 'blocked', now() + interval '1 second');
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin
  if (select count(*) from public.anamnesis_submissions) <> 0 or (select count(*) from public.anamnesis_answers) <> 0 then raise exception 'blocked student can read clinical data'; end if;
  if (select count(*) from public.onboarding_progress) <> 0 then raise exception 'blocked student can read progress'; end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$ declare rejected boolean := false; begin
  begin perform public.review_anamnesis_submission('50000000-0000-0000-0000-000000000001'); exception when others then rejected := true; end;
  if not rejected then raise exception 'trainer reviewed blocked student'; end if;
end $$;
rollback;
