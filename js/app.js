(() => {
  const cfg = window.MASROFI_CONFIG || {};
  const sb = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storage: window.localStorage }
  });
  const $ = id => document.getElementById(id);
  let user = null, profile = null, transactions = [], bills = [], debts = [], goals = [], messages = [];
  const money = n => `${Number(n||0).toLocaleString('ar-EG')} ج.م`;
  const toast = (m, bad=false) => { const t=$('toast'); t.className='toast'; t.style.background=bad?'#dc2626':'#16a34a'; t.textContent=m; setTimeout(()=>{t.className='';t.textContent=''},2600); };
  const need = async (q) => { const {data,error}=await q; if(error) throw error; return data; };
  async function init(){
    bind();
    const { data:{session} } = await sb.auth.getSession();
    if(session?.user) await boot(session.user); else showAuth();
    sb.auth.onAuthStateChange(async (_e, session)=>{ session?.user ? await boot(session.user) : showAuth(); });
  }
  function bind(){
    $('loginBtn').onclick=()=>auth('login'); $('signupBtn').onclick=()=>auth('signup'); $('logoutBtn').onclick=()=>sb.auth.signOut(); $('refreshBtn').onclick=loadAll;
    document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>tab(b.dataset.tab));
    $('saveSalaryBtn').onclick=saveSalary; $('addTxBtn').onclick=addTx; $('addBillBtn').onclick=addBill; $('addDebtBtn').onclick=addDebt; $('addGoalBtn').onclick=addGoal; $('calcBuyBtn').onclick=calcBuy; $('sendChatBtn').onclick=sendChat;
  }
  async function auth(mode){
    try{ $('authMsg').textContent='جاري التنفيذ...'; const email=$('email').value.trim(), password=$('password').value;
      if(!email||!password) throw new Error('اكتب الإيميل والباسورد');
      const res = mode==='signup' ? await sb.auth.signUp({email,password}) : await sb.auth.signInWithPassword({email,password});
      if(res.error) throw res.error; $('authMsg').textContent = mode==='signup' ? 'تم التسجيل، لو التفعيل مطلوب راجع الإيميل.' : 'تم الدخول';
      if(res.data.user) await boot(res.data.user);
    }catch(e){ $('authMsg').textContent=e.message; }
  }
  function showAuth(){ user=null; $('authView').classList.remove('hidden'); $('appView').classList.add('hidden'); }
  async function boot(u){ user=u; $('authView').classList.add('hidden'); $('appView').classList.remove('hidden'); $('userLine').textContent=u.email; await ensureProfile(); await loadAll(); }
  async function ensureProfile(){
    let rows = await need(sb.from('profiles').select('*').eq('user_id', user.id).limit(1));
    if(!rows?.length){ await need(sb.from('profiles').insert({user_id:user.id, monthly_salary:0, salary_day:1})); rows = await need(sb.from('profiles').select('*').eq('user_id', user.id).limit(1)); }
    profile = rows[0]; $('salaryAmount').value=profile.monthly_salary||0; $('salaryDay').value=profile.salary_day||1;
  }
  async function loadAll(){ if(!user) return; try{
    await ensureProfile();
    [transactions,bills,debts,goals,messages] = await Promise.all([
      need(sb.from('transactions').select('*').order('created_at',{ascending:false}).limit(100)),
      need(sb.from('bills').select('*').order('due_date',{ascending:true}).limit(100)),
      need(sb.from('debts').select('*').order('created_at',{ascending:false}).limit(100)),
      need(sb.from('goals').select('*').order('created_at',{ascending:false}).limit(100)),
      need(sb.from('chat_messages').select('*').order('created_at',{ascending:true}).limit(200)),
    ]); render(); toast('تم التحديث');
  }catch(e){ toast(e.message,true); }}
  function tab(id){ document.querySelectorAll('.tab').forEach(x=>x.classList.remove('active')); $(id).classList.add('active'); document.querySelectorAll('[data-tab]').forEach(x=>x.classList.toggle('active',x.dataset.tab===id)); $('pageTitle').textContent=document.querySelector(`[data-tab="${id}"]`).textContent; }
  function render(){
    const income=transactions.filter(x=>x.type==='income').reduce((s,x)=>s+Number(x.amount),0); const expense=transactions.filter(x=>x.type==='expense').reduce((s,x)=>s+Number(x.amount),0); const remaining=Number(profile.monthly_salary||0)+income-expense;
    $('dashboard').innerHTML=[['المرتب',profile.monthly_salary],['دخل إضافي',income],['المصاريف',expense],['المتبقي',remaining],['الفواتير',bills.reduce((s,x)=>s+Number(x.amount),0)],['الأهداف',goals.length]].map(a=>`<div class="metric"><span>${a[0]}</span><b>${money(a[1])}</b></div>`).join('');
    list('txList',transactions,x=>`${x.title||'معاملة'} <small>${x.category||''} - ${x.type}</small>`,x=>money(x.amount),'transactions');
    list('billList',bills,x=>`${x.name} <small>${x.due_date||''}</small>`,x=>money(x.amount),'bills');
    list('debtList',debts,x=>`${x.name} <small>${x.type==='owe'?'عليّا':'ليّا'}</small>`,x=>money(x.amount),'debts');
    list('goalList',goals,x=>`${x.name} <small>${money(x.saved_amount)} / ${money(x.target_amount)}</small>`,x=>`${Math.round((Number(x.saved_amount||0)/Math.max(1,Number(x.target_amount||1)))*100)}%`,'goals');
    $('chatList').innerHTML=messages.map(m=>`<div class="bubble">${esc(m.body)}</div>`).join(''); $('chatList').scrollTop=$('chatList').scrollHeight;
  }
  function list(id,arr,left,right,table){ $(id).innerHTML=arr.map(x=>`<div class="item"><div>${left(x)}</div><b>${right(x)}</b><button class="danger" onclick="Masrofi.del('${table}','${x.id}')">حذف</button></div>`).join('')||'<p class="msg">لا توجد بيانات</p>'; }
  window.Masrofi={del:async(table,id)=>{try{await need(sb.from(table).delete().eq('id',id)); await loadAll();}catch(e){toast(e.message,true)}}};
  async function saveSalary(){ try{ const monthly_salary=Number($('salaryAmount').value||0), salary_day=Math.min(28,Math.max(1,Number($('salaryDay').value||1))); profile=(await need(sb.from('profiles').update({monthly_salary,salary_day,updated_at:new Date().toISOString()}).eq('user_id',user.id).select().single())); render(); toast('تم حفظ المرتب'); }catch(e){toast(e.message,true)} }
  async function addTx(){ try{ await need(sb.from('transactions').insert({user_id:user.id,type:$('txType').value,amount:Number($('txAmount').value||0),title:$('txTitle').value,category:$('txCategory').value})); $('txAmount').value=$('txTitle').value=$('txCategory').value=''; await loadAll(); }catch(e){toast(e.message,true)} }
  async function addBill(){ try{ await need(sb.from('bills').insert({user_id:user.id,name:$('billName').value,amount:Number($('billAmount').value||0),due_date:$('billDue').value||null})); $('billName').value=$('billAmount').value=$('billDue').value=''; await loadAll(); }catch(e){toast(e.message,true)} }
  async function addDebt(){ try{ await need(sb.from('debts').insert({user_id:user.id,name:$('debtName').value,amount:Number($('debtAmount').value||0),type:$('debtType').value})); $('debtName').value=$('debtAmount').value=''; await loadAll(); }catch(e){toast(e.message,true)} }
  async function addGoal(){ try{ await need(sb.from('goals').insert({user_id:user.id,name:$('goalName').value,target_amount:Number($('goalTarget').value||0),saved_amount:Number($('goalSaved').value||0)})); $('goalName').value=$('goalTarget').value=$('goalSaved').value=''; await loadAll(); }catch(e){toast(e.message,true)} }
  function calcBuy(){ const price=Number($('buyPrice').value||0); const income=transactions.filter(x=>x.type==='income').reduce((s,x)=>s+Number(x.amount),0); const expense=transactions.filter(x=>x.type==='expense').reduce((s,x)=>s+Number(x.amount),0); const remaining=Number(profile.monthly_salary||0)+income-expense; const ok=remaining-price; $('buyResult').textContent= price<=0?'اكتب السعر': ok>=0?`تقدر تشتريها، هيتبقى ${money(ok)}`:`الأفضل تستنى، ناقصك ${money(Math.abs(ok))}`; }
  async function sendChat(){ try{ const body=$('chatInput').value.trim(); if(!body)return; await need(sb.from('chat_messages').insert({user_id:user.id,body})); $('chatInput').value=''; await loadAll(); }catch(e){toast(e.message,true)} }
  function esc(s){return String(s||'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));}
  init();
})();
