-- Assessments are append-only and contain only explicitly supplied measurements.
create table public.physical_assessments (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null references public.organizations(id),
 student_id uuid not null references public.profiles(id), created_by uuid not null references public.profiles(id),
 measured_at timestamptz not null default now(), weight_kg numeric(8,2), height_cm numeric(8,2), waist_cm numeric(8,2),
 check (weight_kg is not null or height_cm is not null or waist_cm is not null),
 check (weight_kg is null or (weight_kg > 0 and weight_kg <> 'NaN'::numeric)),
 check (height_cm is null or (height_cm > 0 and height_cm <> 'NaN'::numeric)),
 check (waist_cm is null or (waist_cm > 0 and waist_cm <> 'NaN'::numeric))
);
create index physical_assessments_student_idx on public.physical_assessments(organization_id, student_id, measured_at desc);
alter table public.physical_assessments enable row level security;
create policy physical_assessments_student_read on public.physical_assessments for select to authenticated
 using (private.can_read_own_training(organization_id, student_id));
revoke all on public.physical_assessments from public, anon, authenticated;
grant select on public.physical_assessments to authenticated;

create function private.prevent_assessment_mutation() returns trigger language plpgsql set search_path = '' as $$
begin raise exception 'physical assessments are immutable'; end $$;
create trigger physical_assessments_immutable before update or delete on public.physical_assessments for each row execute function private.prevent_assessment_mutation();
revoke all on function private.prevent_assessment_mutation() from public;

create function public.create_physical_assessment(target_organization uuid, target_student uuid, weight numeric, height numeric, waist numeric)
returns uuid language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
 if not private.can_manage_training(target_organization, target_student) then raise exception 'not authorized'; end if;
 insert into public.physical_assessments(organization_id,student_id,created_by,weight_kg,height_cm,waist_cm)
 values(target_organization,target_student,auth.uid(),weight,height,waist) returning id into result;
 insert into public.audit_logs(organization_id,actor_id,action,entity_type,entity_id,metadata)
 values(target_organization,auth.uid(),'physical_assessment.created','physical_assessment',result,'{}'::jsonb);
 return result;
end $$;
create function public.get_physical_assessments(target_organization uuid, target_student uuid)
returns table(id uuid, measured_at timestamptz, weight_kg numeric, height_cm numeric, waist_cm numeric)
language plpgsql security definer set search_path = '' as $$
begin
 if not private.can_read_staff_training(target_organization, target_student) then raise exception 'not authorized'; end if;
 insert into public.audit_logs(organization_id,actor_id,action,entity_type,entity_id,metadata)
 values(target_organization,auth.uid(),'physical_assessments.reviewed','student',target_student,'{}'::jsonb);
 return query select a.id,a.measured_at,a.weight_kg,a.height_cm,a.waist_cm from public.physical_assessments a
 where a.organization_id=target_organization and a.student_id=target_student order by a.measured_at desc;
end $$;
revoke all on function public.create_physical_assessment(uuid,uuid,numeric,numeric,numeric), public.get_physical_assessments(uuid,uuid) from public, anon;
grant execute on function public.create_physical_assessment(uuid,uuid,numeric,numeric,numeric), public.get_physical_assessments(uuid,uuid) to authenticated;
