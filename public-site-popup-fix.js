/* Public-site popup fix: committee members + shops */
(function(){
  'use strict';

  const MODAL_ID = 'siteDetailPopupFix';
  const STYLE_ID = 'siteDetailPopupFixStyle';

  function esc(s){
    return String(s == null ? '' : s).replace(/[&<>\"']/g, function(c){
      return ({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":'&#39;'}[c]);
    });
  }

  function addStyles(){
    if(document.getElementById(STYLE_ID)) return;
    const style=document.createElement('style');
    style.id=STYLE_ID;
    style.textContent=`
      #${MODAL_ID}{position:fixed;inset:0;z-index:99999;display:none;align-items:center;justify-content:center;padding:18px;background:rgba(18,37,30,.78);backdrop-filter:blur(3px)}
      #${MODAL_ID}.show{display:flex}
      #${MODAL_ID} .pspf-box{width:min(720px,100%);max-height:90vh;overflow:auto;background:#fff;border-radius:20px;box-shadow:0 24px 70px rgba(0,0,0,.28);border:1px solid #e3d8bd}
      #${MODAL_ID} .pspf-head{position:sticky;top:0;z-index:2;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:15px 18px;background:#fff;border-bottom:1px solid #e3d8bd}
      #${MODAL_ID} .pspf-title{margin:0;color:#1f4b43;font-size:1.25rem;font-weight:900}
      #${MODAL_ID} .pspf-close{border:0;width:40px;height:40px;border-radius:50%;background:#f0eee8;color:#1f4b43;font-size:1.35rem;cursor:pointer}
      #${MODAL_ID} .pspf-body{padding:20px}
      #${MODAL_ID} .pspf-body img{display:block;max-width:100%;max-height:430px;width:auto;height:auto;margin:0 auto 18px;border-radius:16px;object-fit:cover}
      #${MODAL_ID} .pspf-card{margin:0!important;box-shadow:none!important;border:0!important;padding:0!important;text-align:center!important;background:transparent!important}
      #${MODAL_ID} .pspf-card h3{margin:5px 0 8px;color:#1f4b43;font-size:1.35rem}
      #${MODAL_ID} .pspf-card p{margin:5px 0;color:#686256;line-height:1.65}
      #${MODAL_ID} .pspf-card .avatar{margin:0 auto 12px}
      #${MODAL_ID} .pspf-actions{display:flex;justify-content:center;flex-wrap:wrap;gap:8px;margin-top:16px}
      #${MODAL_ID} .pspf-actions a{display:inline-block;padding:9px 14px;border-radius:9px;background:#c9a227;color:#1f4b43;text-decoration:none;font-weight:900}
      .people-grid .person,.shop-grid .shop-card{cursor:pointer}
      .people-grid .person:focus,.shop-grid .shop-card:focus{outline:3px solid rgba(201,162,39,.55);outline-offset:3px}
    `;
    document.head.appendChild(style);
  }

  function ensureModal(){
    let m=document.getElementById(MODAL_ID);
    if(m) return m;
    m=document.createElement('div');
    m.id=MODAL_ID;
    m.setAttribute('role','dialog');
    m.setAttribute('aria-modal','true');
    m.innerHTML='<div class="pspf-box"><div class="pspf-head"><h2 class="pspf-title">माहिती</h2><button type="button" class="pspf-close" aria-label="बंद करा">×</button></div><div class="pspf-body"></div></div>';
    document.body.appendChild(m);
    m.addEventListener('click',function(e){ if(e.target===m) closeModal(); });
    m.querySelector('.pspf-close').addEventListener('click',closeModal);
    return m;
  }

  function closeModal(){
    const m=document.getElementById(MODAL_ID);
    if(m) m.classList.remove('show');
    document.body.style.overflow='';
  }

  function isCommitteeCard(el){
    return !!(el && el.closest && el.closest('#committee,.people-grid') && el.closest('.person'));
  }
  function isShopCard(el){
    return !!(el && el.closest && el.closest('#shops,.shop-grid') && el.closest('.shop-card'));
  }

  function targetCard(target){
    if(!target || !target.closest) return null;
    const person=target.closest('.person');
    if(person && isCommitteeCard(person)) return {card:person,type:'committee'};
    const shop=target.closest('.shop-card');
    if(shop && isShopCard(shop)) return {card:shop,type:'shop'};
    return null;
  }

  function shouldOpen(e, cardInfo){
    const t=e.target;
    if(t && t.closest){
      const a=t.closest('a');
      if(a && a.getAttribute('href') && !/^(#|javascript:)/i.test(a.getAttribute('href'))) return false;
      const control=t.closest('button,[role="button"]');
      if(control){
        const txt=(control.textContent||'').trim().toLowerCase();
        if(/close|बंद|×/.test(txt)) return false;
        if(/detail|details|view|more|info|माहिती|तपशील|पहा|अधिक/.test(txt)) return true;
        /* Existing card buttons without a recognizable label are still treated as detail buttons. */
        return cardInfo.type==='committee' || cardInfo.type==='shop';
      }
    }
    return true;
  }

  function cleanClone(card){
    const clone=card.cloneNode(true);
    clone.classList.add('pspf-card');
    clone.removeAttribute('onclick');
    clone.querySelectorAll('[onclick]').forEach(function(n){n.removeAttribute('onclick');});
    clone.querySelectorAll('button').forEach(function(b){b.remove();});
    clone.querySelectorAll('a').forEach(function(a){
      const href=a.getAttribute('href');
      if(href && !/^(tel:|mailto:)/i.test(href)) a.remove();
    });
    return clone;
  }

  function openCard(cardInfo){
    addStyles();
    const m=ensureModal();
    const title=m.querySelector('.pspf-title');
    const body=m.querySelector('.pspf-body');
    title.textContent=cardInfo.type==='committee' ? 'समिती सदस्य / Committee Member' : 'दुकान / Shop Details';
    body.innerHTML='';
    const clone=cleanClone(cardInfo.card);
    body.appendChild(clone);
    m.classList.add('show');
    document.body.style.overflow='hidden';
  }

  function bind(){
    addStyles();
    ['.people-grid .person','#committee .person','.shop-grid .shop-card','#shops .shop-card'].forEach(function(sel){
      document.querySelectorAll(sel).forEach(function(card){
        if(card.dataset.pspfBound==='1') return;
        card.dataset.pspfBound='1';
        card.setAttribute('tabindex',card.getAttribute('tabindex')||'0');
        card.addEventListener('keydown',function(e){
          if(e.key==='Enter' || e.key===' '){e.preventDefault();openCard(targetCard(card));}
        });
      });
    });
  }

  document.addEventListener('click',function(e){
    const info=targetCard(e.target);
    if(!info) return;
    if(!shouldOpen(e,info)) return;
    e.preventDefault();
    e.stopPropagation();
    if(e.stopImmediatePropagation) e.stopImmediatePropagation();
    openCard(info);
  },true);

  document.addEventListener('keydown',function(e){
    if(e.key==='Escape') closeModal();
  });

  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',bind);
  else bind();
  new MutationObserver(bind).observe(document.documentElement,{childList:true,subtree:true});
})();
