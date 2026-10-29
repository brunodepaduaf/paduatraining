-- A trainer's portfolio is assigned by an owner; an old link cannot replace membership.
create or replace function private.can_manage_trainer_link(target_organization uuid, target_trainer uuid, target_student uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select coalesce(private.is_org_owner(target_organization), false);
$$;
create or replace function private.can_read_member(target_organization uuid, target_profile uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select target_profile = (select auth.uid()) or private.is_org_owner(target_organization)
 or (private.member_role_for(target_organization,(select auth.uid())) = 'trainer'::public.member_role
   and private.member_role_for(target_organization,target_profile) = 'student'::public.member_role
   and exists(select 1 from public.trainer_students ts where ts.organization_id=target_organization and ts.trainer_id=(select auth.uid()) and ts.student_id=target_profile and ts.archived_at is null));
$$;
create or replace function private.can_read_profile(target_profile uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select target_profile = (select auth.uid())
 or exists(select 1 from public.trainer_students ts where ts.archived_at is null and ts.student_id=target_profile and ts.trainer_id=(select auth.uid())
   and private.member_role_for(ts.organization_id,(select auth.uid()))='trainer'::public.member_role
   and private.member_role_for(ts.organization_id,target_profile)='student'::public.member_role)
 or exists(select 1 from public.organization_members om where om.profile_id=target_profile and om.archived_at is null and private.is_org_owner(om.organization_id));
$$;
create or replace function private.can_read_student_access(target_organization uuid, target_student uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select (target_student=(select auth.uid()) and private.member_role_for(target_organization,target_student)='student'::public.member_role)
 or private.is_org_owner(target_organization)
 or (private.member_role_for(target_organization,(select auth.uid()))='trainer'::public.member_role
   and private.member_role_for(target_organization,target_student)='student'::public.member_role
   and exists(select 1 from public.trainer_students ts where ts.organization_id=target_organization and ts.student_id=target_student and ts.trainer_id=(select auth.uid()) and ts.archived_at is null));
$$;
create function private.can_read_trainer_link(org uuid, trainer uuid, student uuid) returns boolean
language sql stable security definer set search_path = '' as $$
 select coalesce(private.is_org_owner(org) or ((select auth.uid()) in (trainer,student)
   and private.member_role_for(org,trainer)='trainer'::public.member_role
   and private.member_role_for(org,student)='student'::public.member_role), false);
$$;
revoke all on function private.can_read_trainer_link(uuid,uuid,uuid) from public;
grant execute on function private.can_read_trainer_link(uuid,uuid,uuid) to authenticated;
drop policy "read permitted trainer links" on public.trainer_students;
create policy trainer_links_member_read on public.trainer_students for select to authenticated using (private.can_read_trainer_link(organization_id,trainer_id,student_id));
create function private.guard_trainer_link_identity() returns trigger language plpgsql set search_path = '' as $$
begin
 if (new.id,new.organization_id,new.trainer_id,new.student_id,new.created_by,new.created_at) is distinct from (old.id,old.organization_id,old.trainer_id,old.student_id,old.created_by,old.created_at) then raise exception 'trainer link identity is immutable'; end if;
 return new;
end $$;
create trigger trainer_link_identity_guard before update on public.trainer_students for each row execute function private.guard_trainer_link_identity();
revoke all on function private.guard_trainer_link_identity() from public;
