// backend/edge-functions/create-task/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

type Payload = {
  application_id: string;
  task_type: string;
  due_at: string;
  title?: string;
  description?: string;
};

const VALID_TYPES = ["call", "email", "review"];

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
  }

  try {
    const body = await req.json().catch(() => null);

    if (!body) {
      return new Response(JSON.stringify({ error: "invalid_json" }), { status: 400 });
    }

    const { application_id, task_type, due_at, title, description } = body as Payload;

    if (!application_id || !task_type || !due_at) {
      return new Response(JSON.stringify({ error: "missing_fields" }), { status: 400 });
    }

    if (!VALID_TYPES.includes(task_type)) {
      return new Response(JSON.stringify({ error: "invalid_task_type" }), { status: 400 });
    }

    const due = new Date(due_at);
    if (isNaN(due.getTime())) {
      return new Response(JSON.stringify({ error: "invalid_due_at" }), { status: 400 });
    }
    if (due <= new Date()) {
      return new Response(JSON.stringify({ error: "due_at_in_past" }), { status: 400 });
    }

    // validate application exists
    const { data: app, error: appErr } = await supabase
      .from("applications")
      .select("id, tenant_id")
      .eq("id", application_id)
      .maybeSingle();

    if (appErr) return new Response(JSON.stringify({ error: "db_error" }), { status: 500 });
    if (!app) return new Response(JSON.stringify({ error: "application_not_found" }), { status: 400 });

    const { data, error } = await supabase
      .from("tasks")
      .insert({
        application_id,
        tenant_id: app.tenant_id,
        title: title ?? null,
        description: description ?? null,
        type: task_type,
        due_at: due.toISOString(),
      })
      .select("id")
      .maybeSingle();

    if (error) {
      return new Response(JSON.stringify({ error: "insert_failed" }), { status: 500 });
    }

    return new Response(JSON.stringify({ success: true, task_id: data.id }), { status: 200 });

  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: "internal_error" }), { status: 500 });
  }
});
