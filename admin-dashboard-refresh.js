(()=>{
'use strict';
const SUPA_URL='https://zawatmovyrjcpgxkqcqq.supabase.co';
const KEY='sb_publishable_x9u_XeQlrOil8VRZ6Kcbjg_48JRq51y';
let refreshing=false;
async function refreshAdminDashboard(){
 if(refreshing)return;
 refreshing=true;
 try{
  const db=window.supabase.createClient(SUPA_URL,KEY);
  const s=(await db.auth.getSession()).data.session;
  if(!s){location.replace('portal.html');return;}
  const r=await db.from('profiles').select('id,full_name,email,role,active').eq('id',s.user.id).maybeSingle();
  if(r.error||!r.data||!r.data.active||!['admin','super_admin'].includes(String(r.data.role).toLowerCase())){location.replace('portal.html');return;}
  document.getElementById('login')?.classList.add('hidden');
  document.getElementById('dash')?.classList.remove('hidden');
  document.getElementById('member')?.classList.add('hidden');
  document.getElementById('admin')?.classList.remove('hidden');
  const w=document.getElementById('welcome');if(w)w.textContent='Welcome, '+(r.data.full_name||s.user.email||'Administrator');
  const role=document.getElementById('role');if(role)role.textContent=String(r.data.role).replace('_',' ').toUpperCase();
  const em=document.getElementById('userEmail');if(em)em.textContent=s.user.email||'';
  document.getElementById('logoutBtn')?.classList.remove('hidden');
  if(typeof window.adminLoad==='function') await window.adminLoad();
  else if(typeof window.loadOp==='function') await window.loadOp('members');
 }catch(e){
  const p=document.getElementById('opPanel');
  if(p)p.innerHTML='<div class="error">Dashboard load failed: '+String(e?.message||e)+'</div>';
  console.error('Admin dashboard refresh:',e);
 }finally{refreshing=false;}
}
function bind(){
 document.querySelectorAll('.adminMenu [data-op]').forEach(b=>{
  b.onclick=async()=>{try{if(typeof window.loadOp==='function')await window.loadOp(b.dataset.op);else await refreshAdminDashboard();}catch(e){const p=document.getElementById('opPanel');if(p)p.innerHTML='<div class="error">Unable to load this section: '+String(e?.message||e)+'</div>';}};
 });
}
window.refreshAdminDashboard=refreshAdminDashboard;
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(refreshAdminDashboard,500));
else setTimeout(refreshAdminDashboard,500);
new MutationObserver(bind).observe(document.documentElement,{childList:true,subtree:true});
})();
