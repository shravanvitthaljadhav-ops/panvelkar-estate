(()=>{'use strict';
function add(){
  const nav=document.querySelector('.adminMenu');
  if(!nav || nav.querySelector('[data-op="gallery"]')) return;
  const b=document.createElement('button');
  b.type='button'; b.dataset.op='gallery'; b.innerHTML='📸 <span>Photo Gallery</span>';
  b.addEventListener('click',()=>{
    if(typeof window.loadOp==='function') window.loadOp('gallery');
    else if(typeof window.gallery==='function') window.gallery(document.getElementById('opPanel'));
  });
  nav.appendChild(b);
}
function boot(){ add(); setTimeout(add,300); setTimeout(add,1000); setTimeout(add,2500); }
if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',boot); else boot();
new MutationObserver(add).observe(document.body,{childList:true,subtree:true});
})();