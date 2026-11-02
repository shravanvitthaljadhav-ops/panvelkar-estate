/* V2.0 Supabase adapter. All writes use Admin-gated database RPCs. */
(function(global){'use strict';
const T={units:'payment_units',transactions:'payment_transactions',templates:'payment_templates',settings:'payment_portal_settings'},PAGE=500;
let templateIndex=new Map();
function client(){if(!global.PaymentPortalAuth)throw Error('Authentication module is not loaded.');return global.PaymentPortalAuth.getClient();}
function rows(r,label){if(r.error)throw Error(label+': '+r.error.message);return r.data||[];}
async function all(factory,label){const out=[];for(let n=0;;n+=PAGE){const a=rows(await factory().range(n,n+PAGE-1),label);out.push(...a);if(a.length<PAGE)return out;}}
function txn(t){return{id:t.id,amount:Number(t.amount||0),date:t.payment_date||'',remarks:t.remarks||''};}
function unit(r,tx){const a=tx.map(txn),latest=a.slice().sort((x,y)=>String(y.date).localeCompare(String(x.date)))[0];return{
id:r.id,flat:r.unit_key,name:r.member_name||'',phone:r.mobile_1||'',phones:[r.mobile_2,r.mobile_3].filter(Boolean),
email:r.email||'',otherEmail:r.other_email||'',due:Number(r.total_demand||0),received:Number(r.total_received||0),
balance:Number(r.outstanding||0),payment:r.payment_status||'Pending',wa:r.whatsapp_status||'Pending',
paymentDate:latest?latest.date:(r.payment_date||''),flatStatus:r.flat_status||'',unitType:r.unit_type||'Flat',
wing:r.wing||'',masterUnit:r.unit_key||'',waSentAt:r.whatsapp_sent_at||'',
remarks:(latest&&latest.remarks)||r.remarks||'',openingReceived:Number(r.opening_received||0),
openingReceivedNote:r.opening_received_note||'',transactions:a};}
function mapTemplate(r){return{id:r.system_key||r.id,dbId:r.id,name:r.name,category:r.category||'',message:r.message||'',fileName:r.file_name||'',locked:!!r.is_default,active:!!r.active};}
function dbTemplateId(id){const x=templateIndex.get(String(id||''));return x?x.dbId:(/^[0-9a-f-]{36}$/i.test(String(id||''))?id:null);}
async function rpc(name,args){await global.PaymentPortalAuth.requirePaymentAdmin();const r=await client().rpc(name,args);if(r.error)throw Error(name+': '+r.error.message);return r.data;}
async function loadSnapshot(){
 await global.PaymentPortalAuth.requirePaymentAdmin();
 await rpc('payment_expire_whatsapp_status',{});
 const db=client();
 const units=await all(()=>db.from(T.units).select('id,unit_key,wing,unit_number,unit_type,member_name,flat_status,mobile_1,mobile_2,mobile_3,email,other_email,total_demand,total_received,outstanding,payment_status,whatsapp_status,whatsapp_sent_at,payment_date,remarks,opening_received,opening_received_note').order('wing').order('unit_number'),'Unable to load payment units');
 const ids=units.map(x=>x.id),tx=[];
 for(let i=0;i<ids.length;i+=100){const chunk=ids.slice(i,i+100);tx.push(...await all(()=>db.from(T.transactions).select('id,unit_id,amount,payment_date,remarks,created_at').in('unit_id',chunk).order('payment_date').order('created_at'),'Unable to load transactions'));}
 const by=new Map();tx.forEach(x=>{if(!by.has(x.unit_id))by.set(x.unit_id,[]);by.get(x.unit_id).push(x);});
 const rawTemplates=await all(()=>db.from(T.templates).select('id,system_key,name,category,message,file_name,is_default,active,created_at').order('created_at'),'Unable to load templates');
 const templates=rawTemplates.map(mapTemplate);templateIndex=new Map(templates.map(x=>[String(x.id),x]));
 const ss=await all(()=>db.from(T.settings).select('setting_key,setting_value'),'Unable to load settings');
 const sm=Object.fromEntries(ss.map(x=>[x.setting_key,x.setting_value]));
 const activeDb=sm.active_template_id||'';
 const active=templates.find(x=>x.dbId===activeDb)||null;
 return{data:units.map(x=>unit(x,by.get(x.id)||[])),templateLibrary:templates,activeTemplateId:active?active.id:'',loadedAt:new Date().toISOString()};
}
const api={
 loadSnapshot,
 recordTransaction:(id,amount,date,remarks)=>rpc('payment_record_transaction',{p_unit_id:id,p_amount:Number(amount),p_payment_date:date,p_remarks:remarks||''}),
 updateTransaction:(id,amount,date,remarks)=>rpc('payment_update_transaction',{p_transaction_id:id,p_amount:Number(amount),p_payment_date:date,p_remarks:remarks||''}),
 deleteTransaction:id=>rpc('payment_delete_transaction',{p_transaction_id:id}),
 clearUnitTransactions:id=>rpc('payment_clear_unit_transactions',{p_unit_id:id}),
 setOutstanding:(id,outstanding)=>rpc('payment_set_outstanding',{p_unit_id:id,p_outstanding:Number(outstanding)}),
 bulkSetOutstanding:rows=>rpc('payment_bulk_set_outstanding',{p_rows:rows}),
 updateUnitContact:(id,m1,m2,m3,email)=>rpc('payment_update_unit_contact',{p_unit_id:id,p_mobile_1:m1||'',p_mobile_2:m2||'',p_mobile_3:m3||'',p_email:email||''}),
 updateFlatStatus:(id,status)=>rpc('payment_update_flat_status',{p_unit_id:id,p_flat_status:status||''}),
 updateWhatsAppStatus:(id,status,sentAt)=>rpc('payment_set_whatsapp_status',{p_unit_id:id,p_status:status,p_sent_at:sentAt||null}),
 resetWhatsAppStatuses:()=>rpc('payment_reset_whatsapp_status',{}),
 setActiveTemplate:id=>rpc('payment_set_active_template',{p_template_id:dbTemplateId(id)}),
 saveTemplate:(id,name,category,message,fileName)=>rpc('payment_save_template',{p_template_id:dbTemplateId(id),p_name:name,p_category:category||'General Notice',p_message:message,p_file_name:fileName||''}),
 deleteTemplate:id=>rpc('payment_delete_template',{p_template_id:dbTemplateId(id)}),
 importV20:rows=>rpc('payment_import_v20',{p_rows:rows})
};
global.PaymentPortalData=Object.freeze(api);
})(window);