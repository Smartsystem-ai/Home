import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    const { household_id, message } = await req.json();
    const authHeader = req.headers.get("Authorization")!;
    const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: tx } = await supabase.from("transactions").select("type,category,amount,date").eq("household_id", household_id).order("date", { ascending: false }).limit(80);
    const { data: bills } = await supabase.from("bills").select("bill_name,amount,due_date,status").eq("household_id", household_id).limit(30);
    const context = JSON.stringify({ transactions: tx || [], bills: bills || [] });

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) return new Response(JSON.stringify({ answer: "Gemini API Key غير موجود في Supabase Secrets." }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });

    const prompt = `أنت مساعد مالي عربي لتطبيق Masrofi Smart. حلل مصاريف البيت واقترح خطوات عملية. لا تخترع أرقام خارج البيانات. البيانات: ${context}\nسؤال المستخدم: ${message}`;
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }] }),
    });
    const json = await res.json();
    const answer = json?.candidates?.[0]?.content?.parts?.[0]?.text || "لم أستطع توليد رد.";
    return new Response(JSON.stringify({ answer }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
