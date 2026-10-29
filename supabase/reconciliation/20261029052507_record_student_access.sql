-- The invoker's table privileges and RLS determine who may manage each student.
-- Start times use the database clock, independent of the operator's device clock.
create function public.record_student_access(target_organization uuid, target_student uuid, new_status public.access_period_status, end_at timestamptz default null)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare period_id uuid;
begin
 if new_status not in ('active'::public.access_period_status,'pending'::public.access_period_status,'blocked'::public.access_period_status) then raise exception 'unsupported access status'; end if;
 if end_at is not null and (new_status <> 'active' or end_at <= now()) then raise exception 'end must be in the future for active access'; end if;
 insert into public.access_periods(organization_id,student_id,starts_at,ends_at,status,responsible_id,created_by,updated_by)
 values(target_organization,target_student,now(),end_at,new_status,auth.uid(),auth.uid(),auth.uid()) returning id into period_id;
 return period_id;
end $$;
revoke all on function public.record_student_access(uuid,uuid,public.access_period_status,timestamptz) from public, anon;
grant execute on function public.record_student_access(uuid,uuid,public.access_period_status,timestamptz) to authenticated;
