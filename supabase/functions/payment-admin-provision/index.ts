import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function corsFor(req:Request){
  const origin=req.headers.get("Origin")||"";
  const allowed=/^https:\/\/payments\.(?:panvelkar-estate-stanford\.in|panvelkarestatestanford\.in)$/.test(origin);
  return {
    "Access-Control-Allow-Origin":allowed?origin:"null",
    "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods":"POST, OPTIONS",
    "Vary":"Origin"
  };
}
function reply(body:unknown,status=200,cors:Record<string,string>={}){
  return new Response(JSON.stringify(body),{status,headers:{"Content-Type":"application/json",...cors}});
}
Deno.serve(async(req:Request)=>{
  const cors=corsFor(req);
  if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
  if(req.method!=="POST")return reply({error:"Method not allowed"},405,cors);
  const token=(req.headers.get("Authorization")||"").replace(/^Bearer\s+/i,"");
  if(!token)return reply({error:"Authentication required"},401,cors);
  const url=Deno.env.get("SUPABASE_URL"),anon=Deno.env.get("SUPABASE_ANON_KEY"),service=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if(!url||!anon||!service)return reply({error:"Function environment is incomplete"},500,cors);
  const caller=createClient(url,anon,{global:{headers:{Authorization:"Bearer "+token}},auth:{persistSession:false,autoRefreshToken:false}});
  const {data:{user},error:userErr}=await caller.auth.getUser(token);
  if(userErr||!user)return reply({error:"Invalid session"},401,cors);
  const {data:profile,error:profileErr}=await caller.from("profiles").select("role,active").eq("id",user.id).maybeSingle();
  if(profileErr||profile?.role!=="super_admin"||profile?.active!==true)return reply({error:"Only an active super administrator can manage portal access"},403,cors);
  let body:any;try{body=await req.json();}catch{return reply({error:"Invalid JSON body"},400,cors);}
  if(body.action==="invite"){
    const email=String(body.email||"").trim().toLowerCase();
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))return reply({error:"A valid email address is required"},400,cors);
    const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
    const {data,error}=await admin.auth.admin.inviteUserByEmail(email,{redirectTo:"https://payments.panvelkar-estate-stanford.in/payment-portal.html",data:{invited_for:"payment_portal"}});
    if(error||!data.user)return reply({error:error?.message||"Invitation failed"},400,cors);
    const {error:grantErr}=await caller.rpc("payment_admin_grant",{p_user_id:data.user.id,p_note:"Payment portal invitation"});
    if(grantErr)return reply({error:"Invitation sent but payment access grant failed; owner reconciliation required."},500,cors);
    return reply({success:true,message:"Invitation sent. The user can sign in after setting a password."},200,cors);
  }
  if(body.action==="revoke"){
    const userId=String(body.user_id||"");
    if(!/^[0-9a-f-]{36}$/i.test(userId))return reply({error:"Valid user_id required"},400,cors);
    const {error}=await caller.rpc("payment_admin_revoke",{p_user_id:userId});
    if(error)return reply({error:error.message},400,cors);
    const admin=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
    await admin.auth.admin.signOut(userId,"global");
    return reply({success:true,message:"Payment portal access revoked and refresh sessions invalidated."},200,cors);
  }
  return reply({error:"Unsupported action"},400,cors);
});