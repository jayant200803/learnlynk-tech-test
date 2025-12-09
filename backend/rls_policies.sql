-- backend/rls_policies.sql

alter table public.leads enable row level security;

-- SELECT policy
create policy leads_select_policy on public.leads
for select
using (
  (current_setting('request.jwt.claims', true)::json ->> 'tenant_id') = tenant_id::text
  and
  (
    -- admin sees all leads in tenant
    (current_setting('request.jwt.claims', true)::json ->> 'role') = 'admin'

    -- counselor sees leads they own
    or owner_id::text = (current_setting('request.jwt.claims', true)::json ->> 'user_id')

    -- counselor sees leads from their team members
    or exists (
      select 1
      from public.user_teams ut_c
      join public.user_teams ut_o on ut_c.team_id = ut_o.team_id
      where ut_c.user_id = (current_setting('request.jwt.claims', true)::json ->> 'user_id')::uuid
        and ut_o.user_id = public.leads.owner_id
    )
  )
);

-- INSERT policy
create policy leads_insert_policy on public.leads
for insert
with check (
  (current_setting('request.jwt.claims', true)::json ->> 'tenant_id') = tenant_id::text
  and
  (
    (current_setting('request.jwt.claims', true)::json ->> 'role') = 'admin'
    or owner_id::text = (current_setting('request.jwt.claims', true)::json ->> 'user_id')
    or owner_id is null
  )
);
