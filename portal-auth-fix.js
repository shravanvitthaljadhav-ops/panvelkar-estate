(()=>{
  'use strict';
  if(!window.supabase) return;
  const dbx=window.supabase.createClient('https://zawatmovyrjcpgxkqcqq.supabase.co','sb_publishable_x9u_XeQlrOil8VRZ6Kcbjg_48JRq51y');
  async function getProfile(userId){
    const {data,error}=await dbx.from('profiles').select('id,full_name,email,role,active,unit_id').eq('id',userId).maybeSingle();
    if(error) throw error;
    if(!data) throw new Error('Your account is authenticated but no portal profile was found.');
    if(data.active===false) throw new Error('This portal account is inactive. Please contact the society administrator.');
    return data;
  }
  async function routeAuthenticated(){
    const {data:{user}}=await dbx.auth.getUser();
    if(!user) return false;
    try{
      const p=await getProfile(user.id);
      if(p.role==='member'){
        if(!location.pathname.endsWith('/member-dashboard.html')) location.href='member-dashboard.html';
        return true;
      }
      if(p.role==='admin'||p.role==='super_admin'){
        document.getElementById('login')?.classList.add('hidden');
        document.getElementById('dash')?.classList.remove('hidden');
        document.getElementById('member')?.classList.add('hidden');
        document.getElementById('admin')?.classList.remove('hidden');
        const role=document.getElementById('role'); if(role) role.textContent=p.role.replace('_',' ').toUpperCase();
        const welcome=document.getElementById('welcome'); if(welcome) welcome.textContent='Welcome, '+(p.full_name||user.email||'Administrator');
        const email=document.getElementById('userEmail'); if(email) email.textContent=user.email||'';
        document.getElementById('logoutBtn')?.classList.remove('hidden');
        if(typeof window.loadOp==='function') window.loadOp('members');
        return true;
      }
      throw new Error('This account does not have a valid portal role.');
    }catch(e){
      const msg=document.getElementById('msg');
      if(msg){msg.className='msg error';msg.textContent=e.message||'Unable to load your portal profile.';}
      return false;
    }
  }
  window.login=async function(){
    const email=(document.getElementById('email')?.value||'').trim().toLowerCase();
    const password=document.getElementById('password')?.value||'';
    const msg=document.getElementById('msg');
    if(!email||!password){if(msg){msg.className='msg error';msg.textContent='Please enter email and password.';}return;}
    if(msg){msg.className='msg';msg.textContent='Signing in…';}
    try{
      await dbx.auth.signOut({scope:'local'});
      const {data,error}=await dbx.auth.signInWithPassword({email,password});
      if(error) throw error;
      if(!data?.user) throw new Error('Sign-in completed but no user session was returned.');
      const ok=await routeAuthenticated();
      if(!ok) await dbx.auth.signOut({scope:'local'});
    }catch(e){
      if(msg){msg.className='msg error';msg.textContent=e?.message||'Login failed. Please verify your email and password.';}
      console.error('Portal login:',e);
    }
  };
  window.addEventListener('DOMContentLoaded',()=>setTimeout(routeAuthenticated,150));
})();
