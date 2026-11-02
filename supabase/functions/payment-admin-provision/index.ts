import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "https://payments.panvelkar-estate.in",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};
function reply(body: unknown, status=200) {
  return new Response(JSON.stringify(body), {status,headers:{...cors,"Content-Type":"application/json"}});
}
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok",{headers:cors});
  if (req.method !== "POST") return reply({error:"Method not allowed"},405);
  const authHeader=req.headers.get("Authorization")||"";
  const token=authHeader.replace(/^Bearer\s+/i,"");
  if(!token) return reply({error:"Authentication required"},401);
  const url=Deno.env.get("SUPABASE_URL")!;
  const anon=Deno.env.get("SUPABASE_ANON_KEY")!;
  const service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const caller=createClient(url,anon,{global:{headers:{Authorization:"Bearer "+token}},auth:{persistSession:false,autoRefreshToken:false}});
  const {data:{user},error:userErr}=await caller.auth.getUser(token);
  if(userErr||!user) return reply({error:"Invalid session"},401);
  const {data:profile,error:profileErr}=await caller.from("profiles").select("role,active").eq("id",user.id).maybeSingle();
  if(profileErr||profile?.role!=="super_admin"||profile?.active!==true) return reply({error:"Only an active super administrator can manage portal access"},403);
  let body:any;
  try{body=await req.json();}catch{return reply({error:"Invalid JSON body"},400);}
  if(body.action==="invite"){
    const email=String(body.email||"").trim().toLowerCase();
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return reply({error:"A valid email address is required"},400);
    const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
    const {data,error}=await admin.auth.admin.inviteUserByEmail(email,{data:{invited_for:"payment_portal"}});
    if(error||!data.user) return reply({error:error?.message||"Invitation failed"},400);
    const {error:grantErr}=await caller.rpc("payment_admin_grant",{p_user_id:data.user.id,p_note:"Payment portal invitation"});
    if(grantErr) return reply({error:"Invitation sent but access grant failed. Owner must reconcile: "+grantErr.message},500);
    return reply({success:true,message:"Invitation sent. Access will be available after the invited user sets a password and signs in."});
  }
  if(body.action==="revoke"){
    const userId=String(body.user_id||"");
    if(!/^[0-9a-f-]{36}$/i.test(userId)) return reply({error:"Valid user_id required"},400);
    const {error}=await caller.rpc("payment_admin_revoke",{p_user_id:userId});
    if(error) return reply({error:error.message},400);
    return reply({success:true,message:"Payment portal access revoked. Existing JWTs remain valid until expiry or session revocation."});
  }
  return reply({error:"Unsupported action"},400);
});