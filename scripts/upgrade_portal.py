from pathlib import Path
import re

p = Path('portal.html')
s = p.read_text(encoding='utf-8')

# Idempotence guard
if 'STANFORD MEMBER DASHBOARD V2' in s:
    print('Portal upgrade already applied.')
    raise SystemExit(0)

# Visual layer
css = r'''
<style id="stanford-v2-css">
/* STANFORD MEMBER DASHBOARD V2 */
:root{--stan-teal:#1f4b43;--stan-teal2:#2e6b5e;--stan-sand:#f2e8d5;--stan-cream:#fbf7ef;--stan-brick:#c1502e;--stan-gold:#c9a227;--stan-ink:#25231e;--stan-muted:#686256;--stan-line:#e3d8bd}
body{background:var(--stan-sand);color:var(--stan-ink)}
header{background:linear-gradient(135deg,var(--stan-teal),var(--stan-teal2));border-bottom:4px solid var(--stan-gold)}
#member .section,#member .metric,#memberPanel{background:var(--stan-cream);border-color:var(--stan-line)}
#member .metric b{color:var(--stan-teal)}
#member .serviceTile{border-color:var(--stan-line);background:#fffaf2;min-height:86px}
#member .serviceTile:hover,#member .serviceTile.active{border-color:var(--stan-gold);box-shadow:0 8px 22px #1f4b4318}
.v2-alerts{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-top:14px}
.v2-alert{background:var(--stan-cream);border:1px solid var(--stan-line);border-radius:14px;padding:15px;cursor:pointer}
.v2-alert strong{display:block;color:var(--stan-teal);font-size:16px}.v2-alert span{font-size:12px;color:var(--stan-muted)}
.v2-lang{background:var(--stan-cream);color:var(--stan-teal);border:1px solid var(--stan-gold);border-radius:9px;padding:8px 10px;font-weight:800;margin-right:6px}
.v2-status{padding:5px 9px;border-radius:99px;font-size:12px;font-weight:800}.v2-pending{background:#fff4cf;color:#8a6200}.v2-approved{background:#e8f7ee;color:#176c45}.v2-rejected{background:#fff0ed;color:#a43d27}
@media(max-width:700px){.v2-alerts{grid-template-columns:1fr}.v2-lang{margin-bottom:5px}}
</style>
'''
s = s.replace('</head>', css + '</head>', 1)

# Language selector
old = '<div><button class="ghost" onclick="location.href=\'index.html\'">Public Website</button>'
new = '<div><select id="languageSelect" class="v2-lang" aria-label="Language" onchange="setPortalLanguage(this.value)"><option value="en">English</option><option value="mr">मराठी</option><option value="hi">हिंदी</option></select><button class="ghost" onclick="location.href=\'index.html\'">Public Website</button>'
if old in s:
    s = s.replace(old, new, 1)

# Member Garden tile
needle = '<button class="serviceTile" data-member="complaints">🛠 <b>Complaints</b></button>'
replacement = needle + '<button class="serviceTile" data-member="garden">🌿 <b>Garden Function Booking</b></button>'
if needle in s:
    s = s.replace(needle, replacement, 1)

# Admin Garden tile
needle = '<button class="serviceTile" data-op="notices">📢 <b>Notice Management</b></button>'
replacement = needle + '<button class="serviceTile" data-op="garden">🌿 <b>Garden Booking Requests</b></button>'
if needle in s:
    s = s.replace(needle, replacement, 1)

# Member status cards below the metrics
needle = '<div class="section"><h2>My Property</h2>'
alerts = '''<div class="v2-alerts" id="memberAlerts"><button class="v2-alert" data-member="maintenance"><strong>💰 Pending Maintenance</strong><span>View your latest maintenance dues</span></button><button class="v2-alert" data-member="notices"><strong>📢 Notice</strong><span>View society notices</span></button><button class="v2-alert" data-member="complaints"><strong>🛠 Open Complaint</strong><span>Track your complaints and responses</span></button></div>'''
if needle in s:
    s = s.replace(needle, alerts + needle, 1)

# Add Garden member branch
needle = "if(t==='maintenance'){"
insert = "if(t==='garden'){await gardenMember(p);return}" + needle
if needle in s:
    s = s.replace(needle, insert, 1)

# Add Garden admin branch
needle = "if(op==='notices'){await noticeManagement(p);return}"
insert = needle + "if(op==='garden'){await adminGarden(p);return}"
if needle in s:
    s = s.replace(needle, insert, 1)

# Replace admin complaints UI with explicit status control
pat = re.compile(r"async function adminComplaints\(p\)\{.*?\}async function answerComplaint", re.S)
replacement = r'''async function adminComplaints(p){const r=await db.from('change_requests').select('id,applicant_name,applicant_email,unit_label,complaint_subject,complaint_category,priority,status,admin_note').eq('request_type','complaint').order('created_at',{ascending:false});if(r.error)throw r.error;p.innerHTML='<h2>Complaints Tray</h2><p class="muted">Admin and Super Admin can update status and response. Members cannot approve or close their own complaints.</p><div class="directoryScroll tableWrap"><table><thead><tr><th>Applicant</th><th>Unit</th><th>Subject</th><th>Category</th><th>Priority</th><th>Status</th><th>Response</th><th>Action</th></tr></thead><tbody>'+r.data.map(x=>'<tr><td>'+esc(fmt(x.applicant_name))+'<br><span class="smallNote">'+esc(fmt(x.applicant_email))+'</span></td><td>'+esc(fmt(x.unit_label))+'</td><td>'+esc(fmt(x.complaint_subject))+'</td><td>'+esc(fmt(x.complaint_category))+'</td><td>'+esc(fmt(x.priority))+'</td><td><select id="cstatus'+esc(x.id)+'"><option value="open" '+(x.status==='open'?'selected':'')+'>Open</option><option value="in_progress" '+(x.status==='in_progress'?'selected':'')+'>In Progress</option><option value="resolved" '+(x.status==='resolved'?'selected':'')+'>Resolved</option><option value="closed" '+(x.status==='closed'?'selected':'')+'>Closed</option><option value="rejected" '+(x.status==='rejected'?'selected':'')+'>Rejected</option></select></td><td><textarea id="resp'+esc(x.id)+'">'+esc(x.admin_note||'')+'</textarea></td><td><button class="dark" onclick="answerComplaint('+JSON.stringify(x.id)+')">Update</button></td></tr>').join('')+'</tbody></table></div>'}async function answerComplaint'''
if pat.search(s):
    s = pat.sub(replacement, s, count=1)

# Replace answerComplaint implementation up to residentSearch
pat = re.compile(r"async function answerComplaint\(id\)\{.*?\}async function residentSearch", re.S)
replacement = r'''async function answerComplaint(id){const note=$('resp'+id).value;const status=$('cstatus'+id).value;const payload={admin_note:note,status,admin_response_at:new Date().toISOString(),admin_responded_by:currentProfile.id};if(status==='closed'||status==='resolved')payload.closed_at=new Date().toISOString();const r=await db.from('change_requests').update(payload).eq('id',id);if(r.error)alert(esc(r.error.message));else loadOp('complaints')}async function residentSearch'''
if pat.search(s):
    s = pat.sub(replacement, s, count=1)

# Add Garden functions before adminLoad
marker = 'async function adminLoad()'
garden = r'''async function gardenMember(p){const r=await db.from('garden_area_booking_requests').select('id,event_name,booking_date,start_time,end_time,expected_attendance,additional_info,status,admin_remarks,created_at').eq('requested_by',currentProfile.id).order('created_at',{ascending:false});if(r.error)throw r.error;p.innerHTML='<h2>Garden Area — Function Booking</h2><p class="muted">Submit a request for a function. Admin or Super Admin must approve it before the booking is confirmed.</p><div class="formGrid"><label>Function / Event Name<input id="gardenEvent"></label><label>Booking Date<input id="gardenDate" type="date"></label><label>Start Time<input id="gardenStart" type="time"></label><label>End Time<input id="gardenEnd" type="time"></label><label>Expected Attendance<input id="gardenPeople" type="number" min="1"></label><label class="full">Additional Information<textarea id="gardenInfo" rows="3"></textarea></label></div><div class="row"><button class="dark" onclick="submitGardenBooking()">Send for Admin Approval</button><span id="gardenMsg"></span></div><h3>My Booking Requests</h3><div class="tableWrap"><table><thead><tr><th>Event</th><th>Date</th><th>Time</th><th>People</th><th>Status</th><th>Admin Remarks</th></tr></thead><tbody>'+(r.data||[]).map(x=>'<tr><td>'+esc(x.event_name)+'</td><td>'+esc(x.booking_date)+'</td><td>'+esc((x.start_time||'')+' - '+(x.end_time||''))+'</td><td>'+esc(fmt(x.expected_attendance))+'</td><td><span class="v2-status '+(x.status==='approved'?'v2-approved':x.status==='rejected'?'v2-rejected':'v2-pending')+'">'+esc(x.status||'pending')+'</span></td><td>'+esc(x.admin_remarks||'')+'</td></tr>').join('')+'</tbody></table></div>'}async function submitGardenBooking(){try{const msg=$('gardenMsg');const payload={requested_by:currentProfile.id,unit_id:currentProfile.unit_id,event_name:$('gardenEvent').value.trim(),booking_date:$('gardenDate').value,start_time:$('gardenStart').value,end_time:$('gardenEnd').value,expected_attendance:Number($('gardenPeople').value||0),additional_info:$('gardenInfo').value.trim(),status:'pending'};if(!payload.event_name||!payload.booking_date||!payload.start_time||!payload.end_time||payload.expected_attendance<1)throw Error('Please complete the event, date, time and attendance fields.');const r=await db.from('garden_area_booking_requests').insert(payload);if(r.error)throw r.error;msg.className='ok';msg.textContent='Request sent to Admin for approval.';await gardenMember($('memberPanel'))}catch(e){$('gardenMsg').className='error';$('gardenMsg').textContent=esc(e.message)}}async function adminGarden(p){const r=await db.from('garden_area_booking_requests').select('id,requested_by,unit_id,event_name,booking_date,start_time,end_time,expected_attendance,additional_info,status,admin_remarks,created_at').order('created_at',{ascending:false});if(r.error)throw r.error;p.innerHTML='<h2>Garden Booking Requests</h2><p class="muted">Only Admin and Super Admin can approve, reject or update booking requests.</p><div class="directoryScroll tableWrap"><table><thead><tr><th>Event</th><th>Date</th><th>Time</th><th>Attendance</th><th>Details</th><th>Status</th><th>Admin Remarks</th><th>Action</th></tr></thead><tbody>'+(r.data||[]).map(x=>'<tr><td>'+esc(x.event_name)+'</td><td>'+esc(x.booking_date)+'</td><td>'+esc((x.start_time||'')+' - '+(x.end_time||''))+'</td><td>'+esc(fmt(x.expected_attendance))+'</td><td>'+esc(x.additional_info||'')+'</td><td><select id="gstatus'+esc(x.id)+'"><option value="pending" '+(x.status==='pending'?'selected':'')+'>Pending</option><option value="approved" '+(x.status==='approved'?'selected':'')+'>Approved</option><option value="rejected" '+(x.status==='rejected'?'selected':'')+'>Rejected</option><option value="cancelled" '+(x.status==='cancelled'?'selected':'')+'>Cancelled</option></select></td><td><textarea id="gremark'+esc(x.id)+'">'+esc(x.admin_remarks||'')+'</textarea></td><td><button class="dark" onclick="reviewGarden('+JSON.stringify(x.id)+')">Update</button></td></tr>').join('')+'</tbody></table></div>'}async function reviewGarden(id){const status=$('gstatus'+id).value;const remarks=$('gremark'+id).value;const r=await db.from('garden_area_booking_requests').update({status,admin_remarks:remarks,reviewed_by:currentProfile.id,reviewed_at:new Date().toISOString()}).eq('id',id);if(r.error)alert(esc(r.error.message));else loadOp('garden')}
'''
if marker in s:
    s = s.replace(marker, garden + marker, 1)

# Language support + number translation
lang = r'''const portalTranslations={mr:{'My Property':'माझी मालमत्ता','My Services':'माझ्या सेवा','Society':'सोसायटी','My Profile':'माझे प्रोफाइल','My Flat':'माझा फ्लॅट','Co-Owners':'सह-मालक','Pets':'पाळीव प्राणी','Vehicles':'वाहने','Documents':'कागदपत्रे','Maintenance':'देखभाल','Complaints':'तक्रारी','Funds & Collections':'निधी व वर्गणी','Notices':'सूचना','Projects':'प्रकल्प','Garden Function Booking':'गार्डन कार्यक्रम बुकिंग','Pending Maintenance':'प्रलंबित देखभाल','Open Complaint':'प्रलंबित तक्रार','Notice':'सूचना','Public Website':'सार्वजनिक वेबसाइट','Log out':'बाहेर पडा','Complaints Tray':'तक्रार व्यवस्थापन','Documents':'कागदपत्रे','Garden Booking Requests':'गार्डन बुकिंग विनंत्या'},hi:{'My Property':'मेरी संपत्ति','My Services':'मेरी सेवाएं','Society':'सोसायटी','My Profile':'मेरी प्रोफ़ाइल','My Flat':'मेरा फ्लैट','Co-Owners':'सह-मालिक','Pets':'पालतू जानवर','Vehicles':'वाहन','Documents':'दस्तावेज़','Maintenance':'रखरखाव','Complaints':'शिकायतें','Funds & Collections':'निधि और संग्रह','Notices':'सूचनाएं','Projects':'परियोजनाएं','Garden Function Booking':'गार्डन कार्यक्रम बुकिंग','Pending Maintenance':'लंबित रखरखाव','Open Complaint':'खुली शिकायत','Notice':'सूचना','Public Website':'सार्वजनिक वेबसाइट','Log out':'लॉग आउट','Complaints Tray':'शिकायत प्रबंधन','Garden Booking Requests':'गार्डन बुकिंग अनुरोध'}};function normalizeDigits(v){return String(v).replace(/[०-९]/g,c=>'०१२३४५६७८९'.indexOf(c)).replace(/[٠-٩]/g,c=>'٠١٢٣٤٥٦٧٨٩'.indexOf(c))}function localizeDigits(v,lang){const x=normalizeDigits(v);if(lang==='mr'||lang==='hi')return x.replace(/[0-9]/g,c=>(lang==='mr'?'०१२३४५६७८९':'०१२३४५६७८९')[Number(c)]);return x}function translateTextNodes(root,lang){const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);const nodes=[];while(walker.nextNode())nodes.push(walker.currentNode);nodes.forEach(n=>{if(!n.parentElement||['SCRIPT','STYLE','OPTION'].includes(n.parentElement.tagName))return;let t=n.nodeValue;Object.entries(portalTranslations[lang]||{}).forEach(([a,b])=>{if(t.trim()===a)t=t.replace(a,b)});n.nodeValue=localizeDigits(t,lang)})}function setPortalLanguage(lang){localStorage.setItem('stanfordPortalLanguage',lang);translateTextNodes(document.body,lang);document.documentElement.lang=lang==='mr'?'mr':lang==='hi'?'hi':'en'}document.addEventListener('DOMContentLoaded',()=>{const lang=localStorage.getItem('stanfordPortalLanguage')||'en';const sel=$('languageSelect');if(sel)sel.value=lang;setPortalLanguage(lang)});
'''
# Insert before the auth state listener so it is defined before UI interactions
needle = "db.auth.onAuthStateChange"
if needle in s:
    s = s.replace(needle, lang + needle, 1)

p.write_text(s, encoding='utf-8')
print('Applied Stanford portal V2 integration patches.')
