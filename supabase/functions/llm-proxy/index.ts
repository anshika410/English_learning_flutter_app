// ELLA — llm-proxy Edge Function
// Proxies requests to DeepSeek. Holds the API key server-side; app never sees it.
//
// Request body:  { role: 'conv' | 'judge', prompt: string }
// conv response: { text: string }
// judge response:{ scores: [...] }   — the parsed JSON array from the model
//
// Deploy:  supabase functions deploy llm-proxy --no-verify-jwt
// Secrets: supabase secrets set DEEPSEEK_API_KEY=<your-key>

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const DEEPSEEK_URL = "https://api.deepseek.com/v1/chat/completions";
const CONV_MODEL  = "deepseek-chat";   // conversation (fast, cheap)
const JUDGE_MODEL = "deepseek-chat";   // judge — switch to deepseek-reasoner for higher accuracy

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { role, prompt } = await req.json() as { role: string; prompt: string };

    if (!role || !prompt) {
      return jsonError("Missing role or prompt", 400);
    }
    if (role !== "conv" && role !== "judge") {
      return jsonError(`Unknown role: ${role}`, 400);
    }

    const apiKey = Deno.env.get("DEEPSEEK_API_KEY");
    if (!apiKey) {
      return jsonError("DEEPSEEK_API_KEY not configured", 500);
    }

    const model = role === "conv" ? CONV_MODEL : JUDGE_MODEL;
    const maxTokens = role === "conv" ? 200 : 800;

    const dsResponse = await fetch(DEEPSEEK_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        messages: [{ role: "user", content: prompt }],
        max_tokens: maxTokens,
        temperature: role === "judge" ? 0.0 : 0.8,
      }),
    });

    if (!dsResponse.ok) {
      const err = await dsResponse.text();
      return jsonError(`DeepSeek error ${dsResponse.status}: ${err}`, 502);
    }

    const data = await dsResponse.json() as {
      choices: { message: { content: string } }[];
    };
    const raw = data.choices?.[0]?.message?.content ?? "";

    if (role === "conv") {
      return jsonOk({ text: raw.trim() });
    }

    // judge — parse strict JSON from model response
    // DeepSeek might wrap JSON in markdown fences; strip them.
    const cleaned = raw
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/```\s*$/i, "")
      .trim();

    let parsed: { scores: unknown[] };
    try {
      parsed = JSON.parse(cleaned);
    } catch {
      return jsonError(`judge: model returned non-JSON: ${cleaned.slice(0, 200)}`, 502);
    }

    if (!Array.isArray(parsed.scores)) {
      return jsonError(`judge: missing "scores" array in model output`, 502);
    }

    return jsonOk({ scores: parsed.scores });

  } catch (err) {
    return jsonError(String(err), 500);
  }
});

function jsonOk(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
