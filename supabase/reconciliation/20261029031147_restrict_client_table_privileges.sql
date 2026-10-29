-- These table-level privileges are not governed by RLS. The Data API does not need them.
revoke truncate, references, trigger on public.profiles, public.organizations,
 public.organization_members, public.trainer_students, public.access_periods,
 public.onboarding_progress, public.form_templates, public.form_questions,
 public.anamnesis_submissions, public.anamnesis_answers, public.audit_logs,
 public.exercises from public, anon, authenticated;
revoke all on public.exercises from public, anon, authenticated;
grant select, insert, update on public.exercises to authenticated;
