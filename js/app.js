const $ = (s, root=document) => root.querySelector(s);
const $$ = (s, root=document) => Array.from(root.querySelectorAll(s));
const fmt = (n)=> new Intl.NumberFormat('ar-EG',{style:'currency',currency:'EGP'}).format(Number(n||0));
const num = (v)=> Number(String(v||0).replace(',', '.')) || 0;
function todayISO(){return new Date().toISOString().slice(0,10)}
function monthKey(d=new Date()){return d.toISOString().slice(0,7)}
function escapeHtml(s){return String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}

// حماية عامة من جليتشات الأزرار والـ submit غير المقصود
window.addEventListener('DOMContentLoaded',()=>{
  document.querySelectorAll('button:not([type])').forEach(b=>b.setAttribute('type','button'));
  document.querySelectorAll('form:not([data-allow-submit])').forEach(f=>{
    f.addEventListener('submit',e=>e.preventDefault());
  });
});
window.addEventListener('unhandledrejection',e=>{
  console.error(e.reason);
  if(typeof toast==='function') toast((e.reason&&e.reason.message)||'حصل خطأ غير متوقع، جرب تاني بدون خروج من الحساب.','bad');
});
window.addEventListener('error',e=>{
  console.error(e.error||e.message);
});

function toast(message,type='ok'){
  let t=document.querySelector('.toast');
  if(!t){t=document.createElement('div');t.className='toast';document.body.appendChild(t)}
  t.className='toast show '+type;t.textContent=message;setTimeout(()=>t.classList.remove('show'),3000);
}
function ensureConfig(){
  if(!window.sb){
    const msg='لازم تضيف SUPABASE_URL و SUPABASE_ANON_KEY في js/config.js';
    if(!document.querySelector('.config-error')){const box=document.createElement('div');box.className='config-error';box.textContent=msg;document.body.prepend(box)}
    return false;
  }
  return true;
}
async function getSession(){
  if(!ensureConfig()) return null;
  const {data:{session}, error}=await window.sb.auth.getSession();
  if(error) console.warn('getSession:', error.message);
  if(session) return session;
  // fallback: Supabase sometimes needs an explicit refresh after hard refresh / mobile PWA resume
  try{
    const refreshed=await window.sb.auth.refreshSession();
    return refreshed?.data?.session || null;
  }catch(e){
    console.warn('refreshSession:', e.message);
    return null;
  }
}
async function requireAuth(){ const session=await getSession(); if(!session){ location.href='index.html'; return null;} return session; }
async function logout(){ if(!confirm('هل تريد تسجيل الخروج؟')) return; if(window.sb) await window.sb.auth.signOut(); location.href='index.html'; }
async function getHousehold(){
 const session=await requireAuth();
 if(!session) return null;
 const uid=session.user.id;

 // الطريقة الصارمة: دالة آمنة داخل Supabase تنشئ/ترجع البيت بدون مشاكل RLS
 try{
   const {data,error}=await window.sb.rpc('ensure_current_household');
   if(!error && data && data.length){
     const row=data[0];
     return {id:row.household_id, role:row.role||'owner', member_id:row.member_id||null, name:row.household_name||'بيتي', user:session.user};
   }
   if(error) console.warn('ensure_current_household RPC:', error.message);
 }catch(e){ console.warn('ensure_current_household not available yet:', e.message); }

 // fallback لو ملف SQL المحدث لم يتشغل بعد
 let {data,error}=await window.sb.from('household_users').select('household_id, role, member_id, households(id,name,owner_id)').eq('user_id',uid).eq('status','active').limit(1).maybeSingle();
 if(error){ console.error(error); toast('مشكلة في تحميل بيانات البيت: '+error.message,'bad'); return null; }
 if(!data){
   const meta=session.user.user_metadata||{};
   const homeName=meta.house_name||'بيتي';
   let h=null;
   const existing=await window.sb.from('households').select('id,name,owner_id').eq('owner_id',uid).limit(1).maybeSingle();
   if(existing.error){ console.warn(existing.error.message); }
   h=existing.data;
   if(!h){
     const created=await window.sb.from('households').insert({owner_id:uid,name:homeName}).select('id,name,owner_id').single();
     if(created.error){ toast('تم الدخول لكن لم يتم إنشاء البيت: '+created.error.message,'bad'); return null; }
     h=created.data;
   }
   const link=await window.sb.from('household_users').insert({household_id:h.id,user_id:uid,role:'owner',can_add_expenses:true,can_add_commitments:true,can_view_income:true,can_view_reports:true,can_manage_members:true,status:'active'});
   if(link.error && !String(link.error.message||'').includes('duplicate')){ toast('تم الدخول لكن لم يتم ربط البيت: '+link.error.message,'bad'); return null; }
   data={household_id:h.id,role:'owner',member_id:null,households:h};
 }
 return {id:data.household_id, role:data.role, member_id:data.member_id, name:data.households?.name||'بيتي', user:session.user};
}
function nav(){return `<div class="nav"><div class="container nav-inner"><a class="brand" href="dashboard.html"><span class="brand-mark"><span>م</span></span><span>مصروفي سمارت</span></a><button class="hamb" onclick="document.body.classList.toggle('menu-open')">☰</button><div class="menu"><a href="dashboard.html">الرئيسية</a><a href="ai.html">المستشار الذكي</a><a href="goals.html">الأهداف</a><a href="whatif.html">ماذا لو؟</a><a href="smartbuy.html">هل أقدر أشتريها؟</a><a href="emergency.html">الطوارئ</a><a href="challenges.html">التحديات</a><a href="transactions.html">الشيت</a><a href="bills.html">الفواتير</a><a href="installments.html">الأقساط</a><a href="debts.html">الديون والسلف</a><a href="gam3eya.html">الجمعية</a><a href="members.html">الأفراد</a><a href="notifications.html">الإشعارات</a><button class="btn danger" onclick="logout()">خروج</button></div></div></div>`}
function mountNav(){ if(!ensureConfig()) return; document.body.insertAdjacentHTML('afterbegin',nav()) }
async function addNotification(household_id,user_id,title,body,type='system'){
  const currentUserId = user_id || (await getSession())?.user?.id || null;
  const {error}=await window.sb.from('notifications').insert({household_id,user_id:currentUserId,title,body,type});
  if(error) console.warn(error.message);
}
async function getSettings(H){
  const {data,error}=await window.sb.from('household_settings').select('*').eq('household_id',H.id).maybeSingle();
  if(error && error.code !== 'PGRST116') console.warn(error.message);
  return data || {household_id:H.id, user_id:H.user.id, monthly_salary:0, salary_day:1, emergency_target:0};
}
async function saveSettings(H, payload){
  const row={household_id:H.id, monthly_salary:num(payload.monthly_salary), salary_day:num(payload.salary_day)||1, emergency_target:num(payload.emergency_target)||0, updated_at:new Date().toISOString()};
  const {error}=await window.sb.from('household_settings').upsert(row,{onConflict:'household_id'});
  if(error) throw error;
  toast('تم حفظ إعدادات المرتب');
}
async function financeSummary(H){
  const start = monthKey() + '-01';
  const [settingsRes, txRes, billsRes, instRes, debtsRes, gamRes] = await Promise.all([
    window.sb.from('household_settings').select('*').eq('household_id',H.id).maybeSingle(),
    window.sb.from('transactions').select('*').eq('household_id',H.id).gte('date',start).eq('status','approved'),
    window.sb.from('bills').select('*').eq('household_id',H.id),
    window.sb.from('installments').select('*').eq('household_id',H.id),
    window.sb.from('debts').select('*').eq('household_id',H.id),
    window.sb.from('gam3eyas').select('*').eq('household_id',H.id)
  ]);
  const settings=settingsRes.data || {household_id:H.id,user_id:H.user.id,monthly_salary:0,salary_day:1,emergency_target:0};
  const tx=txRes.data||[], bills=billsRes.data||[], inst=instRes.data||[], debts=debtsRes.data||[], gam3eyas=gamRes?.data||[];
  const actualIncome=tx.filter(x=>x.type==='income').reduce((a,b)=>a+num(b.amount),0);
  const salary=num(settings.monthly_salary);
  const income=Math.max(actualIncome, salary);
  const expenses=tx.filter(x=>x.type==='expense').reduce((a,b)=>a+num(b.amount),0);
  const unpaidBills=bills.filter(x=>x.status!=='paid').reduce((a,b)=>a+num(b.amount),0);
  const installmentsMonthly=inst.filter(x=>x.status!=='finished').reduce((a,b)=>a+num(b.monthly_amount),0);
  const iOwe=debts.filter(x=>x.direction==='i_owe' && x.status!=='paid').reduce((a,b)=>a+Math.max(num(b.amount)-num(b.paid_amount),0),0);
  const owedMe=debts.filter(x=>x.direction==='owes_me' && x.status!=='paid').reduce((a,b)=>a+Math.max(num(b.amount)-num(b.paid_amount),0),0);
  const gam3eyaMonthly=gam3eyas.filter(x=>x.status!=='finished').reduce((a,b)=>a+num(b.monthly_amount),0);
  const commitments=unpaidBills+installmentsMonthly+iOwe+gam3eyaMonthly;
  const remaining=income-expenses-commitments;
  const safeToSpend=Math.max(remaining-num(settings.emergency_target),0);
  const byCat={}; tx.filter(x=>x.type==='expense').forEach(x=>byCat[x.category]=(byCat[x.category]||0)+num(x.amount));
  const topCats=Object.entries(byCat).sort((a,b)=>b[1]-a[1]).slice(0,5);
  return {settings, tx, bills, inst, debts, gam3eyas, gam3eyaMonthly, income, actualIncome, salary, expenses, unpaidBills, installmentsMonthly, iOwe, owedMe, commitments, remaining, safeToSpend, topCats};
}
function normalizeArabicNumber(text=''){
  const map={'٠':'0','١':'1','٢':'2','٣':'3','٤':'4','٥':'5','٦':'6','٧':'7','٨':'8','٩':'9'};
  return String(text).replace(/[٠-٩]/g,d=>map[d]).replace(/جنيه|جنيها|ج/g,'').trim();
}
function detectAmount(text){const t=normalizeArabicNumber(text); const m=t.match(/(\d+(?:[\.,]\d+)?)/); return m?Number(m[1].replace(',','.')):0}
function detectName(t){
  const m=t.match(/(?:من|لـ|ل|عند|على)\s+([\u0600-\u06FFa-zA-Z ]{2,20})/); return m?m[1].trim():'غير محدد';
}
function smartParse(text){
  const raw=(text||'').trim(); const t=normalizeArabicNumber(raw).toLowerCase(); const amount=detectAmount(t);
  const cats=[['أكل','اكل','طعام','مطعم','سوبر ماركت','سوبرماركت','طلبات'],['مواصلات','تاكسي','اوبر','بنزين','مترو'],['كهرباء','نور'],['مياه','مية'],['غاز'],['انترنت','نت','واي فاي'],['إيجار','ايجار'],['مرتب','راتب','دخل','قبض'],['دواء','صيدلية','دكتور'],['مدرسة','دراسة','تعليم'],['لبس','ملابس'],['ترفيه','خروجة','سينما']];
  let category='عام'; for(const group of cats){ if(group.some(w=>t.includes(w))){category=group[0]; break;} }
  if(/مرتب|راتب|salary|قبضي|قبضى/.test(t)) return {action:'settings', monthly_salary:amount, salary_day:1, note:raw};
  if(/جمعية|الجمعية/.test(t)) return {action:'gam3eya',name:raw.includes('جمعية')?'جمعية':'جمعية شهرية',monthly_amount:amount,total_members:12,current_turn:1,my_turn:null,start_date:todayISO(),status:'active',note:raw};
  if(/عايز|نفسي|اشتري|اجيب|هدف|مشروع|سفر|مصيف|شقة|موبايل|لابتوب|عربية|سيارة/.test(t) && amount>0) return {action:'idea_plan', target_amount:amount, months:detectMonths(t), idea:raw, note:raw};
  if(/احوش|تحويش|ادخر|ادخار|وفر|اوفير|خطة/.test(t)) return {action:'saving_plan', note:raw};
  if(/حلل|تحليل|ملخص|المتبقي|رصيدي|فاضل/.test(t)) return {action:'analyze', note:raw};
  if(/امسح|احذف/.test(t)) return {action:'help', note:'الحذف من الجدول مباشرة بزر حذف لكل عملية لضمان عدم حذف شيء بالغلط.'};
  if(/فاتورة|فواتير/.test(t) || ['كهرباء','مياه','غاز','انترنت'].includes(category)) return {action:'bill',bill_name:category,amount,due_date:null,status:/دفعت|مدفوعة/.test(t)?'paid':'unpaid',note:raw};
  if(/قسط|اقساط/.test(t)) return {action:'installment',title:category==='عام'?'قسط':category,total_amount:amount,monthly_amount:amount,total_months:1,paid_months:/دفعت/.test(t)?1:0,next_due_date:null,note:raw};
  if(/سلفة|دين|مديون|استلف|سلفت|دَين/.test(t)) return {action:'debt',person_name:detectName(t),direction:/ليا|ليّ|سلفت|هو مديون|عنده/.test(t)?'owes_me':'i_owe',amount,paid_amount:0,due_date:null,status:'open',note:raw};
  const type=/دخل|قبض|استلمت|وصلني/.test(t)?'income':'expense';
  return {action:'transaction',type,category:type==='income' && category==='عام'?'دخل':category,amount,date:todayISO(),status:'approved',note:raw};
}
async function saveSmartEntry(H, parsed){
  if(parsed.action==='analyze') return await analyzeMonth(H);
  if(parsed.action==='saving_plan') return await savingPlan(H);
  if(parsed.action==='idea_plan') return await ideaSavingChat(H, parsed.idea || parsed.note || '');
  if(parsed.action==='gam3eya') {
    if(!parsed.monthly_amount) throw new Error('قول قيمة الجمعية الشهرية، مثال: جمعية 1000 في الشهر');
    const {error}=await window.sb.from('gam3eyas').insert({household_id:H.id,created_by:H.user.id,name:parsed.name||'جمعية شهرية',monthly_amount:parsed.monthly_amount,total_members:parsed.total_members||12,current_turn:parsed.current_turn||1,my_turn:parsed.my_turn||null,start_date:parsed.start_date||todayISO(),status:parsed.status||'active',note:parsed.note||''});
    if(error) throw error;
    return `تم تسجيل الجمعية بقسط شهري ${fmt(parsed.monthly_amount)}. هتتحسب ضمن التزامات الشهر.`;
  }
  if(parsed.action==='help') return parsed.note;
  if(parsed.action==='settings'){
    if(!parsed.monthly_salary) throw new Error('قول مرتبك كام بوضوح، مثال: مرتبي 15000');
    const old=await getSettings(H); await saveSettings(H,{...old, monthly_salary:parsed.monthly_salary}); return `تمام، حفظت مرتبك الشهري ${fmt(parsed.monthly_salary)}. هحسب المتبقي بناءً عليه كل شهر.`;
  }
  if(!parsed.amount || parsed.amount<=0) throw new Error('مش قادر أحدد المبلغ. اكتب أو قول المبلغ بوضوح.');
  if(parsed.action==='transaction'){
    const status=H.role==='member'?'pending':'approved';
    const payload={household_id:H.id,created_by:H.user.id,assigned_to_member_id:H.member_id,type:parsed.type,category:parsed.category,amount:parsed.amount,note:parsed.note,date:parsed.date||todayISO(),status};
    const {error}=await window.sb.from('transactions').insert(payload); if(error) throw error;
    await addNotification(H.id,null,'عملية جديدة',`${parsed.category} - ${fmt(parsed.amount)}`,'transaction');
    return `تم تسجيل ${parsed.type==='income'?'دخل':'مصروف'}: ${parsed.category} بقيمة ${fmt(parsed.amount)}.`;
  }
  if(parsed.action==='bill'){
    const {error}=await window.sb.from('bills').insert({household_id:H.id,created_by:H.user.id,bill_name:parsed.bill_name||'فاتورة',amount:parsed.amount,due_date:parsed.due_date||null,status:parsed.status||'unpaid'}); if(error) throw error;
    return `تم تسجيل فاتورة ${parsed.bill_name||'فاتورة'} بقيمة ${fmt(parsed.amount)}.`;
  }
  if(parsed.action==='installment'){
    const {error}=await window.sb.from('installments').insert({household_id:H.id,created_by:H.user.id,title:parsed.title||'قسط',total_amount:parsed.total_amount||parsed.amount,monthly_amount:parsed.monthly_amount||parsed.amount,total_months:parsed.total_months||1,paid_months:parsed.paid_months||0,next_due_date:parsed.next_due_date||null}); if(error) throw error;
    return `تم تسجيل القسط: ${parsed.title||'قسط'} بقيمة ${fmt(parsed.monthly_amount||parsed.amount)}.`;
  }
  if(parsed.action==='debt'){
    const {error}=await window.sb.from('debts').insert({household_id:H.id,created_by:H.user.id,person_name:parsed.person_name||'غير محدد',direction:parsed.direction||'i_owe',amount:parsed.amount,paid_amount:parsed.paid_amount||0,due_date:parsed.due_date||null,status:parsed.status||'open'}); if(error) throw error;
    return `تم تسجيل ${parsed.direction==='owes_me'?'سلفة ليك':'دين عليك'} بقيمة ${fmt(parsed.amount)}.`;
  }
  throw new Error('نوع الطلب غير معروف.');
}

function detectMonths(text=''){
  const t=normalizeArabicNumber(text);
  let m=t.match(/(?:خلال|في)\s+(\d+)\s*(?:شهر|شهور|اشهر)/);
  if(m) return Number(m[1]);
  m=t.match(/(?:خلال|في)\s+(\d+)\s*(?:سنة|سنين|عام)/);
  if(m) return Number(m[1])*12;
  if(/سنة|عام/.test(t)) return 12;
  return 0;
}
async function ideaSavingChat(H, text=''){
  const s=await financeSummary(H);
  const raw=(text||'').trim();
  const amount=detectAmount(raw);
  const months=detectMonths(raw);
  if(!s.income) return 'قبل ما أرتبلك الفكرة لازم أعرف دخلك. اكتب: مرتبي 15000';
  if(!raw) return `قولّي الفكرة بالتفصيل: عايز تحوش لإيه؟ محتاج كام؟ وخلال قد إيه؟\nمثال: عايز أشتري موبايل بـ 20000 خلال 5 شهور.\n\nوضعك الحالي سريعًا: الدخل ${fmt(s.income)}، الالتزامات ${fmt(s.commitments)}، المصاريف ${fmt(s.expenses)}، المتبقي ${fmt(s.remaining)}.`;
  if(!amount) return `الفكرة مفهومة، لكن ناقصني المبلغ. اكتب مثلًا: ${raw} بـ 20000 خلال 6 شهور.\nوضعك الحالي: المتبقي المتوقع ${fmt(s.remaining)}.`;
  if(!months) return `تمام، الهدف تقريبًا ${fmt(amount)}. ناقصني المدة: عايز توصله خلال كام شهر؟\nمثال: ${raw} خلال 6 شهور.`;
  const monthlyNeeded=Math.ceil(amount/months);
  const currentSafe=Math.max(s.remaining,0);
  const gap=Math.max(monthlyNeeded-currentSafe,0);
  const topCuts=s.topCats.slice(0,3).map(([k,v])=>`- ${k}: مصروفك ${fmt(v)}، جرّب تقلله ${fmt(Math.ceil(v*0.15))} شهريًا`).join('\n');
  let plan=`خطة تنفيذ الفكرة\nالفكرة: ${raw}\nالمبلغ المطلوب: ${fmt(amount)}\nالمدة: ${months} شهر\nلازم تحوش شهريًا: ${fmt(monthlyNeeded)}\nالمتبقي المتوقع عندك شهريًا بعد الالتزامات والمصاريف: ${fmt(s.remaining)}\n`;
  if(s.remaining>=monthlyNeeded){
    plan+=`\nالوضع مناسب. تقدر تعمل هدف ثابت باسم الفكرة وتحوش ${fmt(monthlyNeeded)} أول ما المرتب ينزل، ولسه هيبقى معاك تقريبًا ${fmt(s.remaining-monthlyNeeded)} مرونة.`;
  }else{
    plan+=`\nحاليًا ناقصك حوالي ${fmt(gap)} شهريًا عشان تحقق الهدف في المدة دي.\nالحلول المقترحة:\n1) زوّد المدة إلى ${Math.ceil(amount/Math.max(currentSafe,1))} شهر تقريبًا بدون ضغط.\n2) قلل من أكبر البنود:\n${topCuts || '- سجّل مصاريفك أولًا عشان أحددلك البنود اللي تتقص.'}\n3) لو عندك ديون عليك ${fmt(s.iOwe)}، الأفضل نعمل أولوية لسداد القريب قبل الهدف لو عليه ضغط.`;
  }
  const questions=[];
  if(s.iOwe>0) questions.push('هل الديون اللي عليك لازم تتسدد قبل الهدف ده؟');
  if(!s.topCats.length) questions.push('سجّل مصاريف أسبوع واحد على الأقل عشان الخطة تبقى أدق.');
  questions.push('هل الهدف ضروري ولا رفاهية؟ عشان أحدد نسبة ضغط التحويش.');
  questions.push('هل عندك دخل إضافي ممكن يدخل في الخطة؟');
  plan+=`\n\nأسئلتي عشان أظبطها معاك:\n- ${questions.join('\n- ')}`;
  return plan;
}

async function savingPlan(H){
  const s=await financeSummary(H);
  if(!s.income) return 'لازم أعرف دخلك الأول. اكتب: مرتبي 15000';
  const fixed=s.commitments;
  const flex=s.expenses;
  const rem=s.remaining;
  const target=Math.max(Math.round(s.income*0.15), num(s.settings.emergency_target)||0);
  const daily=Math.max(Math.floor(s.safeToSpend/30),0);
  const questions=[];
  if(!s.settings.emergency_target) questions.push('عايز تحوش كام كاحتياطي ثابت كل شهر؟');
  if(!s.topCats.length) questions.push('إيه أكتر 3 بنود بتصرف فيهم عادة؟');
  if(s.iOwe>0) questions.push('هل الديون اللي عليك ليها تاريخ سداد قريب؟');
  let txt=`خطة التحويش المقترحة\nالدخل: ${fmt(s.income)}\nالالتزامات الثابتة: ${fmt(fixed)}\nالمصاريف المسجلة: ${fmt(flex)}\nالمتبقي المتوقع: ${fmt(rem)}\nالهدف المقترح للتحويش: ${fmt(target)}\nالمتاح اليومي الآمن: ${fmt(daily)}\n`;
  if(rem<target) txt += `\nلازم تقلل مصاريف بنحو ${fmt(target-rem)} عشان توصل لهدف التحويش.`;
  else txt += `\nممكن تحوش ${fmt(target)} وتسيب ${fmt(rem-target)} كمرونة لباقي الشهر.`;
  txt += `\n\nأسئلتي عشان أرتبها أدق:\n- ${questions.join('\n- ') || 'هل عندك هدف معين: سفر، جهاز، طوارئ، أو سداد دين؟'}`;
  return txt;
}
async function analyzeMonth(H){
  const s=await financeSummary(H);
  const top=s.topCats.map(([k,v])=>`${k}: ${fmt(v)}`).join('، ')||'لا يوجد صرف حتى الآن';
  let advice='';
  if(!s.salary && !s.actualIncome) advice='ابدأ بتسجيل مرتبك: “مرتبي 15000”.';
  else if(s.remaining<0) advice='أنت داخل في عجز هذا الشهر. قلل المصاريف غير الأساسية أو راجع الأقساط/الفواتير.';
  else if(s.expenses > s.income*0.7) advice='الصرف عالي مقارنة بالدخل. حاول تحدد ميزانية للأكل والمواصلات.';
  else advice='الوضع مستقر. تقدر تطلب: احوش ازاي؟ وأنا أطلع لك خطة شهرية وأسألك الأسئلة الناقصة.';
  return `تحليل الشهر الحالي\nالدخل/المرتب: ${fmt(s.income)}\nالمصاريف المسجلة: ${fmt(s.expenses)}\nالالتزامات المفتوحة: ${fmt(s.commitments)}\nالمتبقي المتوقع: ${fmt(s.remaining)}\nالمتاح الآمن للصرف: ${fmt(s.safeToSpend)}\nديون عليك: ${fmt(s.iOwe)}\nفلوس ليك عند الناس: ${fmt(s.owedMe)}\nالجمعيات الشهرية: ${fmt(s.gam3eyaMonthly||0)}\nأعلى بنود صرف: ${top}\nالنصيحة: ${advice}`;
}
async function healthScore(H){
  const s=await financeSummary(H);
  if(!s.income) return {score:0,label:'سجل دخلك أولًا',tips:['اكتب: مرتبي 15000']};
  let score=100;
  const expenseRatio=s.expenses/s.income;
  const debtRatio=s.iOwe/s.income;
  const commitmentRatio=s.commitments/s.income;
  if(expenseRatio>0.45) score-=Math.min(30,Math.round((expenseRatio-0.45)*100));
  if(commitmentRatio>0.55) score-=25;
  if(s.remaining<0) score-=35;
  if(debtRatio>0.3) score-=15;
  if(s.safeToSpend<=0) score-=10;
  score=Math.max(0,Math.min(100,score));
  const tips=[];
  if(s.remaining<0) tips.push('أوقف أي مشتريات غير ضرورية لحد نهاية الشهر.');
  if(s.iOwe>0) tips.push('رتّب الديون حسب أقرب ميعاد سداد وابدأ بالأصغر أو الأكثر إلحاحًا.');
  if(s.topCats[0]) tips.push(`أكبر بند صرف هو ${s.topCats[0][0]} بقيمة ${fmt(s.topCats[0][1])}؛ قلله 10–20%.`);
  if(!tips.length) tips.push('وضعك مستقر؛ ابدأ هدف ادخار ثابت أول الشهر.');
  const label=score>=80?'ممتاز':score>=60?'مستقر':score>=40?'محتاج ضبط':'خطر';
  return {score,label,tips};
}
function parseGoalText(text=''){
  const amount=detectAmount(text); const months=detectMonths(text)||1;
  let title=String(text||'هدف جديد').replace(/[0-9٠-٩]+/g,'').replace(/ب|بـ|خلال|شهر|شهور|سنة|عام/g,'').trim();
  if(!title) title='هدف جديد';
  return {title, target_amount:amount, deadline_months:months};
}
async function saveGoal(H, goal){
  const payload={household_id:H.id, created_by:H.user.id, title:goal.title||'هدف جديد', target_amount:num(goal.target_amount), saved_amount:num(goal.saved_amount)||0, deadline_months:num(goal.deadline_months)||1, priority:goal.priority||'medium', status:goal.status||'active', note:goal.note||''};
  if(!payload.target_amount) throw new Error('اكتب مبلغ الهدف.');
  const q=goal.id ? window.sb.from('goals').update(payload).eq('id',goal.id) : window.sb.from('goals').insert(payload);
  const {error}=await q; if(error) throw error;
  toast(goal.id?'تم تعديل الهدف':'تم إضافة الهدف');
}
async function consultantReply(H,text=''){
  const s=await financeSummary(H);
  const h=await healthScore(H);
  const raw=(text||'').trim(); const amount=detectAmount(raw); const months=detectMonths(raw);
  const lower=normalizeArabicNumber(raw).toLowerCase();
  if(!s.income) return 'قبل ما أجاوبك بجد لازم أعرف دخلك الشهري. اكتب: مرتبي 15000';
  if(/هل اقدر|اقدر اشتري|اشتريها|اشتري/.test(lower) && amount){
    const impact=s.remaining-amount;
    if(impact>=0) return `تقدر تشتريها نظريًا، لكن الأفضل ما تدفعش أكتر من المتاح الآمن.
سعرها: ${fmt(amount)}
المتبقي بعد الشراء: ${fmt(impact)}
المتاح الآمن الحالي: ${fmt(s.safeToSpend)}
رأيي: ${amount<=s.safeToSpend?'مقبولة':'ممكنة لكن هتضغط الشهر؛ الأفضل تقسيمها أو تأجيلها.'}`;
    return `لا أنصح بالشراء الآن. السعر ${fmt(amount)} وهيعمل عجز حوالي ${fmt(Math.abs(impact))}.
الحل: أجل الشراء أو حوّشه على ${Math.ceil(amount/Math.max(s.safeToSpend,1))} شهر تقريبًا.`;
  }
  if(/هدف|عايز|نفسي|احوش|اشتري|سفر|موبايل|لابتوب|مشروع|شقة|عربية/.test(lower)) return await ideaSavingChat(H, raw);
  if(/دين|ديون|سلفة|سلف/.test(lower)){
    return `خطة الديون المختصرة:
إجمالي الديون عليك: ${fmt(s.iOwe)}
فلوس ليك عند الناس: ${fmt(s.owedMe)}
المتبقي الشهري: ${fmt(s.remaining)}
الخطة: خصص أولًا ${fmt(Math.max(Math.round(s.income*0.1), Math.min(s.remaining, s.iOwe)))} للسداد شهريًا لو المتبقي يسمح.
سؤالي: أقرب دين مطلوب إمتى؟ ومين أهم شخص لازم يتسدد الأول؟`;
  }
  if(/جمعية/.test(lower)){
    const maxMonthly=Math.max(0,Math.floor(s.remaining*0.45));
    return `بالنظر لوضعك الحالي، أقصى قسط جمعية آمن تقريبًا ${fmt(maxMonthly)} شهريًا.
الجمعيات الحالية: ${fmt(s.gam3eyaMonthly)}
لو دخلت جمعية أعلى من الرقم ده هتضغط السيولة.
سؤالي: دورك هتقبضه بدري ولا متأخر؟`;
  }
  return `تحليلي الحالي:
الصحة المالية: ${h.score}/100 (${h.label})
الدخل: ${fmt(s.income)}
المصاريف: ${fmt(s.expenses)}
الالتزامات: ${fmt(s.commitments)}
المتبقي: ${fmt(s.remaining)}

نصيحتي الآن:
- ${h.tips.join('\n- ')}

اسألني بصيغة واضحة مثل: “عايز أشتري موبايل بـ 20000 خلال 5 شهور” أو “أدخل جمعية 1500؟”.`;
}

async function purchaseDecision(H,{name='الشراء',price=0,months=0}={}){
  const s=await financeSummary(H);
  const itemName=String(name||'الشراء').trim()||'الشراء';
  const amount=num(price);
  const m=num(months);
  if(!amount) return 'اكتب سعر الحاجة عشان أحسب القرار.';
  if(!s.income) return 'لازم تسجل المرتب/الدخل الشهري الأول من الرئيسية عشان القرار يبقى صحيح.';

  const safe=s.safeToSpend;
  const afterCash=s.remaining-amount;
  const monthlyNeeded=m>0 ? Math.ceil(amount/m) : amount;
  const afterMonthly=s.remaining-monthlyNeeded;
  const commitmentRatio=s.income ? (s.commitments/s.income) : 0;
  const expenseRatio=s.income ? (s.expenses/s.income) : 0;

  let status='مرفوض حاليًا';
  let verdict='لا أنصح بالشراء الآن.';
  let reason=[];

  if(amount<=safe && afterCash>=0){
    status='مسموح نقدًا';
    verdict='تقدر تشتريها نقدًا بدون ما تكسر الأمان الشهري.';
  }else if(m>0 && monthlyNeeded<=Math.max(safe,0) && afterMonthly>=0){
    status='مسموح بالتقسيط/التحويش';
    verdict=`الأفضل تحوش أو تقسطها على ${m} شهر بقيمة ${fmt(monthlyNeeded)} شهريًا.`;
  }else if(afterCash>=0 && amount>s.safeToSpend){
    status='ممكن لكن خطر';
    verdict='ممكن تدفعها، لكنها هتدخل في منطقة غير آمنة وتقلل الاحتياطي.';
  }

  if(s.remaining<0) reason.push('عندك عجز متوقع هذا الشهر، فالأولوية لإيقاف الصرف غير الضروري.');
  if(commitmentRatio>0.55) reason.push('نسبة الالتزامات عالية بالنسبة للدخل.');
  if(expenseRatio>0.45) reason.push('مصاريف الشهر عالية، حاول تقلل أكبر بند قبل الشراء.');
  if(s.iOwe>0) reason.push(`عليك ديون/سلف بقيمة ${fmt(s.iOwe)}؛ الأفضل ترتيبها قبل أي شراء رفاهي.`);
  if(amount>s.safeToSpend) reason.push(`السعر أعلى من المتاح الآمن للصرف: ${fmt(s.safeToSpend)}.`);

  const monthsToSave = Math.ceil(amount / Math.max(safe,1));
  const topCuts = s.topCats.slice(0,2).map(([k,v])=>`${k}: قلله 10–15%`).join('، ');

  return `قرار ${itemName}: ${status}
${verdict}

السعر: ${fmt(amount)}
الدخل الشهري: ${fmt(s.income)}
المصاريف المسجلة: ${fmt(s.expenses)}
الالتزامات: ${fmt(s.commitments)}
المتبقي المتوقع: ${fmt(s.remaining)}
المتاح الآمن: ${fmt(s.safeToSpend)}
بعد الشراء نقدًا: ${fmt(afterCash)}
${m>0?`لو على ${m} شهر: ${fmt(monthlyNeeded)} شهريًا، والمتبقي بعد القسط: ${fmt(afterMonthly)}\n`:''}
${reason.length?'أسباب القرار:\n- '+reason.join('\n- '):'أسباب القرار:\n- وضعك يسمح بشراء محسوب بدون ضغط واضح.'}

الخطة الآمنة:
- ${safe>0?`لو هتحوش من المتاح الآمن فقط، تحتاج تقريبًا ${monthsToSave} شهر.`:'ابدأ بتسجيل/تقليل المصاريف عشان يظهر متاح آمن.'}
- ${topCuts || 'سجل مصاريفك أسبوع عشان أحدد البنود اللي تتقص.'}`;
}

function simulateWhatIf(s,{incomeDelta=0,expenseCut=0,newCommitment=0,target=0}={}){
  const newIncome=s.income+num(incomeDelta);
  const newExpenses=Math.max(0,s.expenses-num(expenseCut));
  const newCommit=s.commitments+num(newCommitment);
  const remaining=newIncome-newExpenses-newCommit;
  const months=target?Math.ceil(num(target)/Math.max(remaining,1)):0;
  return {newIncome,newExpenses,newCommit,remaining,months};
}

async function deleteRow(table,id){ if(!confirm('متأكد من الحذف؟')) return; const {error}=await window.sb.from(table).delete().eq('id',id); if(error) return toast(error.message,'bad'); toast('تم الحذف'); if(typeof load==='function') load(); }
function fillForm(formId,row){const form=$(formId); if(!form) return; Object.entries(row).forEach(([k,v])=>{const el=form.querySelector(`[name="${k}"],#${k}`); if(el) el.value=v??''}); const id=form.querySelector('[name="id"],#id'); if(id) id.value=row.id||''; window.scrollTo({top:0,behavior:'smooth'});}
async function saveGeneric(table, payload, id){
  let res; if(id) res=await window.sb.from(table).update(payload).eq('id',id); else res=await window.sb.from(table).insert(payload);
  if(res.error) throw res.error; toast(id?'تم التعديل':'تم الحفظ');
}
