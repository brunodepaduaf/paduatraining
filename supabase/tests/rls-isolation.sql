\set ON_ERROR_STOP on
begin;

create schema auth;
create table auth.users (id uuid primary key);
create or replace function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create role authenticated nologin;

\i /workspace/supabase/migrations/202610290001_foundation.sql

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
end $$;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin
  if (select count(*) from public.anamnesis_submissions) <> 0 then raise exception 'owner has direct clinical read'; end if;
  if (select public.review_anamnesis_submission('50000000-0000-0000-0000-000000000001') is not null) is not true then raise exception 'owner cannot use audited RPC'; end if;
end $$;
rollback;
