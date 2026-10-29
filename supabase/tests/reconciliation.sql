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
\ir ../reconciliation/20261029030224_exercise_catalog.sql
-- Reproduce the Supabase defaults observed on the existing test project.
grant truncate, references, trigger, maintain on all tables in schema public to anon, authenticated;
alter default privileges in schema public grant truncate, references, trigger, maintain on tables to anon, authenticated;
\ir ../reconciliation/20261029031147_restrict_client_table_privileges.sql
\ir ../reconciliation/20261029031355_restrict_table_default_privileges.sql
\ir ../reconciliation/20261029032358_training_prescriptions.sql
\ir ../reconciliation/20261029033539_training_sessions.sql
\ir ../reconciliation/20261029050746_physical_assessments.sql
\ir ../reconciliation/20261029051542_private_training_chat.sql
\ir ../reconciliation/20261029052037_access_period_precedence.sql
\ir ../reconciliation/20261029052507_record_student_access.sql
do $$ declare t text; role_name text; begin foreach t in array array['profiles','organizations','organization_members','trainer_students','access_periods','onboarding_progress','form_templates','form_questions','anamnesis_submissions','anamnesis_answers','audit_logs','exercises'] loop foreach role_name in array array['anon','authenticated'] loop if has_table_privilege(role_name, 'public.' || t, 'truncate') or has_table_privilege(role_name, 'public.' || t, 'references') or has_table_privilege(role_name, 'public.' || t, 'trigger') or has_table_privilege(role_name, 'public.' || t, 'maintain') then raise exception 'unsafe table grants on % for %', t, role_name; end if; end loop; end loop; end $$;
create table public.synthetic_default_privilege_probe (id integer);
do $$ begin if has_table_privilege('anon','public.synthetic_default_privilege_probe','truncate') or has_table_privilege('authenticated','public.synthetic_default_privilege_probe','maintain') then raise exception 'unsafe default privileges'; end if; end $$;
do $$ begin if has_table_privilege('anon', 'public.exercises', 'select') or has_table_privilege('authenticated', 'public.exercises', 'truncate') or has_table_privilege('authenticated', 'public.exercises', 'delete') then raise exception 'exercise grants are too broad'; end if; end $$;
insert into auth.users(id) values ('00000000-0000-0000-0000-000000000001'), ('00000000-0000-0000-0000-000000000002'), ('00000000-0000-0000-0000-000000000003'), ('00000000-0000-0000-0000-000000000004'), ('00000000-0000-0000-0000-000000000005');
insert into public.organizations(id, name, created_by) values ('10000000-0000-0000-0000-000000000001','Org sintética A','00000000-0000-0000-0000-000000000001'), ('20000000-0000-0000-0000-000000000001','Org sintética B','00000000-0000-0000-0000-000000000004');
insert into public.organization_members(organization_id,profile_id,role) values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','owner'), ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','trainer'), ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','student'), ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000004','owner'), ('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000005','student');
insert into public.trainer_students(organization_id,trainer_id,student_id,created_by) values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001');
insert into public.access_periods(organization_id,student_id,starts_at,status,responsible_id,created_by,updated_by) values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',now()-interval '1 day','active','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001');
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
-- Exercise data are synthetic and scoped to the organization.
insert into public.exercises(id,organization_id,name,instructions,created_by) values ('60000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Exercício sintético','Instruções sintéticas','00000000-0000-0000-0000-000000000001');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000004';
insert into public.exercises(id,organization_id,name,created_by) values ('60000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','Exercício sintético B','00000000-0000-0000-0000-000000000004');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
insert into public.training_plans(id,organization_id,student_id,created_by,title,version) values ('70000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','Rascunho sintético',2);
insert into public.training_plan_items(plan_id,exercise_id,position,sets,repetitions) values ('70000000-0000-0000-0000-000000000002','60000000-0000-0000-0000-000000000001',1,2,'10');
delete from public.training_plans where id='70000000-0000-0000-0000-000000000002';
insert into public.training_plans(id,organization_id,student_id,created_by,title,version) values ('70000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','Treino sintético',1);
insert into public.training_plan_items(id,plan_id,exercise_id,position,sets,repetitions) values ('80000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001',1,3,'10');
do $$ declare denied boolean:=false; begin begin insert into public.training_plan_items(plan_id,exercise_id,position,sets,repetitions) values ('70000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000002',2,2,'10'); exception when others then denied:=true; end; if not denied then raise exception 'cross-organization exercise accepted'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin if (select count(*) from public.training_plans) <> 0 or (select count(*) from public.training_plan_items) <> 0 then raise exception 'student can see draft'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
update public.training_plans set status='published' where id='70000000-0000-0000-0000-000000000001';
update public.exercises set instructions='Nova instrução sintética' where id='60000000-0000-0000-0000-000000000001';
do $$ begin if (select exercise_instructions from public.training_plan_items where id='80000000-0000-0000-0000-000000000001') <> 'Instruções sintéticas' then raise exception 'published exercise snapshot changed'; end if; end $$;
do $$ declare denied boolean:=false; begin begin update public.training_plan_items set sets=4 where id='80000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end; if not denied and (select sets from public.training_plan_items where id='80000000-0000-0000-0000-000000000001') <> 3 then raise exception 'published workout was mutable'; end if; end $$;
select public.create_physical_assessment('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',70,175,80);
reset role;
do $$ declare denied boolean:=false; begin begin update public.physical_assessments set weight_kg=71 where organization_id='10000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end; if not denied then raise exception 'assessment mutable'; end if; end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ declare denied boolean:=false; begin begin perform public.create_physical_assessment('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',null,null,null); exception when others then denied:=true; end; if not denied then raise exception 'empty assessment accepted'; end if; end $$;
insert into public.form_templates(id,organization_id,title,version,created_by,description) values ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Anamnese sintética',1,'00000000-0000-0000-0000-000000000001','Descrição sintética');
insert into public.form_questions(id,template_id,position,prompt,question_type,required) values ('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001',1,'Pergunta sintética','text',true);
update public.form_templates set status = 'published' where id='30000000-0000-0000-0000-000000000001';
do $$ declare denied boolean := false; begin
 begin update public.form_questions set prompt='Alterada' where id='40000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end;
 if not denied then raise exception 'published question mutable'; end if;
end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin if (select count(*) from public.form_templates) <> 1 then raise exception 'student cannot read published template'; end if; if (select count(*) from public.exercises) <> 0 then raise exception 'student can read staff catalog'; end if; if (select count(*) from public.training_plan_items) <> 1 then raise exception 'student cannot read own published training'; end if; if (select count(*) from public.physical_assessments) <> 1 then raise exception 'student cannot read own assessment'; end if; end $$;
insert into public.training_sessions(id,organization_id,student_id,plan_id) values ('90000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','70000000-0000-0000-0000-000000000001');
do $$ declare denied boolean:=false; begin begin update public.training_sessions set status='completed',completed_at=now() where id='90000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end; if not denied then raise exception 'incomplete session accepted'; end if; end $$;
insert into public.training_session_items(session_id,plan_item_id,completed) values ('90000000-0000-0000-0000-000000000001','80000000-0000-0000-0000-000000000001',true);
update public.training_sessions set status='completed',completed_at=now() where id='90000000-0000-0000-0000-000000000001';
do $$ declare denied boolean:=false; begin begin update public.training_sessions set completed_at=now()+interval '1 day' where id='90000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end; if not denied then raise exception 'completed session mutable'; end if; end $$;
update public.training_session_items set completed=false where session_id='90000000-0000-0000-0000-000000000001';
do $$ begin if (select completed from public.training_session_items where session_id='90000000-0000-0000-0000-000000000001') is distinct from true then raise exception 'completed session item mutable'; end if; end $$;
do $$ declare denied boolean:=false; begin
 begin perform public.create_physical_assessment('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',70,null,null); exception when others then denied:=true; end;
 if not denied then raise exception 'student could create assessment'; end if;
end $$;
do $$ begin if (select count(*) from public.get_training_chat_contacts('10000000-0000-0000-0000-000000000001')) <> 1 then raise exception 'student missing chat contact'; end if; end $$;
select public.send_training_chat_message('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','Mensagem sintética');
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
insert into public.exercises(organization_id,name,created_by) values ('10000000-0000-0000-0000-000000000001','Outro exercício sintético','00000000-0000-0000-0000-000000000002');
do $$ declare denied boolean:=false; begin begin insert into public.exercises(organization_id,name,created_by) values ('20000000-0000-0000-0000-000000000001','Indevido','00000000-0000-0000-0000-000000000002'); exception when others then denied:=true; end; if not denied then raise exception 'cross-organization insert'; end if; end $$;
do $$ begin if (select count(*) from public.exercises) <> 2 then raise exception 'trainer cannot read catalog'; end if; if (select count(*) from public.training_plans) <> 1 then raise exception 'trainer cannot read linked training'; end if; if (select count(*) from public.training_sessions) <> 0 or (select count(*) from public.physical_assessments) <> 0 then raise exception 'trainer has direct sensitive access'; end if; if (select count(*) from public.get_physical_assessments('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003')) <> 1 then raise exception 'trainer cannot review assessment'; end if; if (select count(*) from public.get_training_session_summary('00000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001')) <> 1 then raise exception 'trainer cannot review session summary'; end if; if (select count(*) from public.anamnesis_answers) <> 0 then raise exception 'trainer has direct clinical access'; end if; if public.get_anamnesis_submission_for_trainer('50000000-0000-0000-0000-000000000001') is null then raise exception 'linked trainer cannot review'; end if; end $$;
do $$ begin if (select count(*) from public.get_training_chat_messages('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003')) <> 1 then raise exception 'linked trainer cannot read chat'; end if; end $$;
select public.send_training_chat_message('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','Resposta sintética');
reset role;
do $$ declare denied boolean:=false; begin begin update public.training_chat_messages set body='alterada' where organization_id='10000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end; if not denied then raise exception 'chat message mutable'; end if; if exists(select 1 from public.audit_logs where action like 'training_chat.%' and metadata <> '{}'::jsonb) then raise exception 'chat content leaked to audit metadata'; end if; end $$;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ declare denied boolean:=false; begin begin perform public.get_training_chat_messages('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003'); exception when others then denied:=true; end; if not denied then raise exception 'non-participant owner can read chat'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
select public.create_physical_assessment('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',71,null,null);
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000004';
do $$ begin if (select count(*) from public.form_templates) <> 0 or (select count(*) from public.exercises) <> 1 or (select count(*) from public.training_plans) <> 0 then raise exception 'cross-organization access'; end if; end $$;
do $$ declare denied boolean:=false; begin begin perform public.get_training_session_summary('00000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001'); exception when others then denied:=true; end; if not denied then raise exception 'cross-organization session summary'; end if; denied:=false; begin perform public.get_physical_assessments('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003'); exception when others then denied:=true; end; if not denied then raise exception 'cross-organization assessment'; end if; denied:=false; begin perform public.get_training_chat_messages('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003'); exception when others then denied:=true; end; if not denied then raise exception 'cross-organization chat'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin if (select count(*) from public.anamnesis_answers) <> 0 then raise exception 'owner has direct clinical access'; end if; if public.get_anamnesis_submission_for_owner('50000000-0000-0000-0000-000000000001') is null then raise exception 'owner cannot review'; end if; end $$;
update public.exercises set archived_at=now() where id='60000000-0000-0000-0000-000000000001';
do $$ declare denied boolean:=false; begin begin update public.exercises set name='Alterado' where id='60000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end; if not denied then raise exception 'archived exercise mutable'; end if; end $$;
update public.form_templates set status='archived' where id='30000000-0000-0000-0000-000000000001';
do $$ declare denied boolean:=false; begin begin update public.form_questions set prompt='alterada' where id='40000000-0000-0000-0000-000000000001'; exception when others then denied:=true; end; if not denied then raise exception 'archived question mutable'; end if; end $$;
insert into public.access_periods(organization_id,student_id,starts_at,status,responsible_id,created_by,updated_by) values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',now()-interval '1 hour','blocked','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001');
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin if (select count(*) from public.anamnesis_answers) <> 0 or (select count(*) from public.onboarding_progress) <> 0 or (select count(*) from public.training_plans) <> 0 or (select count(*) from public.training_sessions) <> 0 or (select count(*) from public.physical_assessments) <> 0 then raise exception 'blocked student retained access'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$ declare denied boolean:=false; begin begin perform public.get_anamnesis_submission_for_trainer('50000000-0000-0000-0000-000000000001'); exception when others then denied:=true; end; if not denied then raise exception 'trainer reviewed blocked student'; end if; denied:=false; begin perform public.get_physical_assessments('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003'); exception when others then denied:=true; end; if not denied then raise exception 'trainer reviewed blocked assessment'; end if; denied:=false; begin perform public.get_training_chat_messages('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003'); exception when others then denied:=true; end; if not denied then raise exception 'trainer reviewed blocked chat'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
update public.access_periods set status='active' where status='blocked' and student_id='00000000-0000-0000-0000-000000000003';
reset role;
update public.organization_members set archived_at=now() where profile_id='00000000-0000-0000-0000-000000000003';
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin if (select count(*) from public.anamnesis_answers) <> 0 or (select count(*) from public.onboarding_progress) <> 0 then raise exception 'archived member retained access'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
do $$ begin if (select count(*) from public.training_plans) <> 1 then raise exception 'owner lost training history'; end if; if (select count(*) from public.get_training_session_summary('00000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001')) <> 1 then raise exception 'owner lost session history'; end if; end $$;
-- An expired latest period cannot reveal an older, still-open active period.
reset role;
update public.organization_members set archived_at=null where profile_id='00000000-0000-0000-0000-000000000003';
insert into public.access_periods(organization_id,student_id,starts_at,ends_at,status,responsible_id,created_by,updated_by,updated_at,created_at) values
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',now()-interval '5 days',null,'active','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',now()+interval '1 second',now()+interval '1 second'),
 ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',now()-interval '2 days',now()-interval '1 day','active','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',now()+interval '2 seconds',now()+interval '2 seconds');
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin if (select count(*) from public.training_plans) <> 0 or (select count(*) from public.physical_assessments) <> 0 then raise exception 'expired access revived an older period'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
do $$ declare denied boolean:=false; begin begin perform public.get_training_chat_messages('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003'); exception when others then denied:=true; end; if not denied then raise exception 'trainer read expired student chat'; end if; end $$;
reset role;
insert into public.access_periods(organization_id,student_id,starts_at,status,responsible_id,created_by,updated_by,updated_at,created_at) values ('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003',now()+interval '1 day','active','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',now()+interval '3 seconds',now()+interval '3 seconds');
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000003';
do $$ begin if (select count(*) from public.training_plans) <> 0 then raise exception 'future period granted access early'; end if; end $$;

-- Only staff authorized by RLS may record a new access period.
do $$ declare denied boolean:=false; begin begin perform public.record_student_access('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','active',null); exception when others then denied:=true; end; if not denied then raise exception 'student changed access'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
select public.record_student_access('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','blocked',null);
do $$ declare denied boolean:=false; begin begin perform public.record_student_access('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000005','active',null); exception when others then denied:=true; end; if not denied then raise exception 'trainer changed another organization access'; end if; end $$;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
select public.record_student_access('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','active',now()+interval '1 day');
do $$ declare denied boolean:=false; begin
 begin perform public.record_student_access('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000003','active',now()-interval '1 second'); exception when others then denied:=true; end;
 if not denied then raise exception 'past access end accepted'; end if;
 if not exists(select 1 from public.audit_logs where action='access_period.created' and actor_id='00000000-0000-0000-0000-000000000001') then raise exception 'access change was not audited'; end if;
end $$;
rollback;
