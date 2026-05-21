import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async () => {
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const today = new Date().toISOString().slice(0, 10);
  const { data: households } = await supabase.from("households").select("id,owner_id,name");
  for (const h of households || []) {
    const { data: bills } = await supabase.from("bills").select("*").eq("household_id", h.id).neq("status", "paid");
    const due = (bills || []).filter((b) => b.due_date && b.due_date <= today);
    await supabase.from("notifications").insert({
      household_id: h.id,
      user_id: h.owner_id,
      title: "ملخص Masrofi Smart اليومي",
      body: `لديك ${due.length} فواتير مستحقة/متأخرة و ${bills?.length || 0} فواتير مفتوحة.`,
      type: "daily",
    });
  }
  return new Response(JSON.stringify({ ok: true }));
});
