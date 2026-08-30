/**
 * Supabase Edge Function: permanently delete the authenticated Juicd account.
 *
 * The iOS client sends only the user's access token. The service-role key is
 * injected by Supabase at runtime and must never be included in the app.
 *
 * Deploy after reviewing the linked project's auth setup:
 *   supabase functions deploy delete-account
 *
 * Supabase's JWT gateway and this function both verify the bearer token. The
 * function never accepts a user ID from the request body. Public user-owned
 * rows use ON DELETE CASCADE where appropriate; analytics/error rows
 * intentionally retain only an anonymized null user_id through ON DELETE SET
 * NULL.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function bearerToken(req: Request): string | null {
  const header = req.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const token = bearerToken(req);
  if (!token) return json({ error: "authentication_required" }, 401);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      throw new Error("Supabase service configuration is missing");
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: authData, error: authError } = await admin.auth.getUser(token);
    if (authError || !authData.user) return json({ error: "invalid_session" }, 401);

    const { error: deleteError } = await admin.auth.admin.deleteUser(authData.user.id);
    if (deleteError) throw new Error(`Could not delete auth user: ${deleteError.message}`);

    return json({ deleted: true });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});
