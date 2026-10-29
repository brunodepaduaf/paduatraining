-- PostgreSQL 17 MAINTAIN is also outside RLS; client roles do not need it.
revoke maintain on public.profiles, public.organizations, public.organization_members,
 public.trainer_students, public.access_periods, public.onboarding_progress,
 public.form_templates, public.form_questions, public.anamnesis_submissions,
 public.anamnesis_answers, public.audit_logs, public.exercises from public, anon, authenticated;
-- Apply this migration as the role that creates application tables (postgres in Supabase).
-- Keep ordinary Data API grants unchanged; RLS remains the row authorization boundary.
alter default privileges in schema public revoke truncate, references, trigger, maintain on tables from public, anon, authenticated;
