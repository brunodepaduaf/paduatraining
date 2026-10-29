\set ON_ERROR_STOP on
-- Run only on a new, disposable PostgreSQL database as a role able to create roles.
begin;
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key, raw_user_meta_data jsonb not null default '{}');
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth to authenticated, anon;
create schema storage;
create table storage.buckets (id text primary key, name text, public boolean);
\ir ../reconciliation/remote-history.sql
\ir ../reconciliation/20261029023003_reconcile_existing_anamnesis.sql
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002'), ('00000000-0000-0000-0000-000000000003'), ('00000000-0000-0000-0000-000000000004'), ('00000000-0000-0000-0000-000000000005');
insert into public.organizations(id, name, created_by) values ('10000000-0000-0000-0000-000000000001','Org sintética A','00000000-0000-0000-0000-000000000001'), ('20000000-0000-0000-0000-000000000001','Org sintética B','00000000-0000-0000-0000-000000000004');
insert into public.organization_members(organization_id,profile_id,role) values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','owner'), ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','trainer'), ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','student'), ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000004','owner'), ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000005','student');
insert into public.trainer_students(organization_id,trainer_id,student_id,created_by) values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001');
insert into public.access_periods(organization_id,student_id,starts_at,status,responsible_id,created_by,updated_by) values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',now()-interval '1 day','active','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001');
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
insert into public.form_templates(id,organization_id,title,version,created_by,description) values ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Anamnese sintética',1,'00000000-0000-0000-0000-000000000001','Descrição sintética');
insert into public.form_questions(id,template_id,position,prompt,question_type,required) values ('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',1,'Pergunta sintética','text',true);
update public.form_templates set status = 'published' where id='30000000-0000-0000-0000-000000000001';
do $$ declare denied boolean := false; begin
 begin update public.form_questions set prompt='Alterada' where id='40000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end;
 if not denied then raise exception 'published question mutable'; end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin if (select count(*) from public.form_templates) <> 1 then raise exception 'student cannot read published template'; end if; end $$;
insert into public.onboarding_progress(organization_id,student_id,tour_step) values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',1);
insert into public.anamnesis_submissions(id,organization_id,student_id,template_id) values ('50000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000001');
do $$ declare denied boolean := false; begin
 begin update public.anamnesis_submissions set status='submitted',submitted_at=now() where id='50000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end;
 if not denied then raise exception 'missing required answer accepted'; end if;
end $$;
insert into public.anamnesis_answers(submission_id,question_id,response) values ('50000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','"sintético"');
delete from public.anamnesis_answers where submission_id='50000000-0000-0000-0000-000000000001';
insert into public.anamnesis_answers(submission_id,question_id,response) values ('50000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001','"sintético"');
update public.anamnesis_submissions set status='submitted',submitted_at=now() where id='50000000-0000-0000-0000-000000000001';
do $$ declare denied boolean := false; begin
 begin delete from public.anamnesis_answers where submission_id='50000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end;
 if not denied then raise exception 'submitted answer deleted'; end if;
 denied:=false; begin update public.anamnesis_submissions set submitted_at=now()+interval '1 day' where id='50000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end;
 if not denied then raise exception 'submitted submission mutable'; end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$ begin if (select count(*) from public.anamnesis_answers) <> 0 then raise exception 'trainer has direct clinical access'; end if; if public.get_anamnesis_submission_for_trainer('50000000-0000-0000-0000-000000000001') is null then raise exception 'linked trainer cannot review'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000004';
do $$ begin if (select count(*) from public.form_templates) <> 0 then raise exception 'cross-organization access'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin if (select count(*) from public.anamnesis_answers) <> 0 then raise exception 'owner has direct clinical access'; end if; if public.get_anamnesis_submission_for_owner('50000000-0000-0000-0000-000000000001') is null then raise exception 'owner cannot review'; end if; end $$;
update public.form_templates set status='archived' where id='30000000-0000-0000-0000-000000000001';
do $$ declare denied boolean:=false; begin begin update public.form_questions set prompt='alterada' where id='40000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end; if not denied then raise exception 'archived question mutable'; end if; end $$;
insert into public.access_periods(organization_id,student_id,starts_at,status,responsible_id,created_by,updated_by) values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',now()-interval '1 hour','blocked','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin if (select count(*) from public.anamnesis_answers) <> 0 or (select count(*) from public.onboarding_progress) <> 0 then raise exception 'blocked student retained access'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$ declare denied boolean:=false; begin begin perform public.get_anamnesis_submission_for_trainer('50000000-0000-0000-0000-000000000001'); exception when others then denied:=true; end; if not denied then raise exception 'trainer reviewed blocked student'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
update public.access_periods set status='active' where status='blocked' and student_id='00000000-0000-0000-0000-000000000003';
reset role;
update public.organization_members set archived_at=now() where profile_id='00000000-0000-0000-0000-000000000003';
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin if (select count(*) from public.anamnesis_answers) <> 0 or (select count(*) from public.onboarding_progress) <> 0 then raise exception 'archived member retained access'; end if; end $$;
rollback;
