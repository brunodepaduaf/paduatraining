-- Expiration of the latest started period must never reactivate an older period.
create or replace function private.has_active_student_access(target_organization uuid, target_student uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select coalesce(private.member_role_for(target_organization, target_student) = 'student'::public.member_role, false)
   and private.can_read_student_access(target_organization, target_student)
   and coalesce((select ap.status = 'active'::public.access_period_status and (ap.ends_at is null or ap.ends_at > now())
     from public.access_periods ap where ap.organization_id = target_organization and ap.student_id = target_student and ap.starts_at <= now()
     order by ap.updated_at desc, ap.created_at desc, (ap.status <> 'active'::public.access_period_status) desc, ap.id desc limit 1), false);
$$;
