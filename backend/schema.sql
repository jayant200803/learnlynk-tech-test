-- backend/schema.sql
-- LearnLynk Tech Test - Schema (ready for Supabase / Postgres)
create extension if not exists "pgcrypto";

-- tenants table (optional but required for tenant scoping)
create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text,
  created_at timestamptz not null default now()
);

-- leads table
create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  owner_id uuid,
  full_name text,
  email text,
  phone text,
  stage text not null default 'new',
  source text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- applications table
create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  lead_id uuid not null references public.leads(id) on delete cascade,
  program_id uuid,
  intake_id uuid,
  stage text not null default 'inquiry',
  status text not null default 'open',
  amount numeric,
  payment_status text default 'unpaid',
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- tasks table
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  application_id uuid not null references public.applications(id) on delete cascade,
  title text,
  type text not null,
  description text,
  assigned_to uuid,
  status text not null default 'open',
  due_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tasks_valid_type check (type in ('call','email','review')),
  constraint tasks_due_after_created check (due_at >= created_at)
);

-- indexes
create index if not exists idx_leads_tenant_owner_stage_created on public.leads (tenant_id, owner_id, stage, created_at);
create index if not exists idx_applications_tenant_lead on public.applications (tenant_id, lead_id);
create index if not exists idx_tasks_tenant_due_status on public.tasks (tenant_id, due_at, status);

-- updated_at triggers
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_update_leads_updated_at
before update on public.leads
for each row execute function update_updated_at_column();

create trigger trg_update_applications_updated_at
before update on public.applications
for each row execute function update_updated_at_column();

create trigger trg_update_tasks_updated_at
before update on public.tasks
for each row execute function update_updated_at_column();

-- realtime notify (optional but helpful)
create or replace function notify_task_created()
returns trigger as $$
begin
  perform pg_notify('task.created', row_to_json(NEW)::text);
  return NEW;
end;
$$ language plpgsql;

drop trigger if exists tasks_notify_trigger on public.tasks;
create trigger tasks_notify_trigger
after insert on public.tasks
for each row execute function notify_task_created();
