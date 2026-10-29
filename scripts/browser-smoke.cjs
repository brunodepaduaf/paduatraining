// Browser smoke tests use a fully synthetic API and never contact external services.
const { chromium } = require('playwright-core');
const { Buffer } = require('node:buffer');
const { spawnSync } = require('node:child_process');
const { mkdtempSync, rmSync, existsSync, readFileSync } = require('node:fs');
const { tmpdir } = require('node:os');
const { join, resolve, extname, sep } = require('node:path');
const { createServer } = require('node:http');
const assert = require('node:assert/strict');
const outDir = mkdtempSync(join(tmpdir(), 'padua-browser-'));
const candidates = [process.env.CHROMIUM_PATH, '/usr/bin/chromium', '/usr/bin/google-chrome', '/usr/bin/chromium-browser'].filter(Boolean);
const browserPath = candidates.find(existsSync);
if (!browserPath) { console.error('Set CHROMIUM_PATH to an installed Chromium or Chrome executable.'); rmSync(outDir, { recursive: true, force: true }); process.exit(1); }
const build = spawnSync(process.execPath, [require.resolve('expo/bin/cli'), 'export', '--platform', 'web', '--clear', '--output-dir', outDir], { stdio: 'inherit', env: { ...process.env, EXPO_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:7654', EXPO_PUBLIC_SUPABASE_ANON_KEY: 'synthetic-anon-key', EXPO_NO_TELEMETRY: '1' } });
if (build.status !== 0) { rmSync(outDir, { recursive: true, force: true }); process.exit(build.status || 1); }
const server = createServer((req, res) => {
 const pathname = decodeURIComponent(new URL(req.url, 'http://127.0.0.1').pathname);
 const route = pathname === '/' ? '/index.html' : ['/reset-password', '/sign-in', '/workspace'].includes(pathname) ? `${pathname}.html` : pathname;
 const path = resolve(outDir, `.${route}`);
 if (!path.startsWith(resolve(outDir) + sep)) { res.writeHead(403).end(); return; }
 try { const data = readFileSync(path); const types = { '.html': 'text/html', '.js': 'application/javascript', '.ttf': 'font/ttf', '.woff2': 'font/woff2', '.css': 'text/css' }; res.writeHead(200, { 'Content-Type': types[extname(path)] || 'application/octet-stream' }); res.end(data); } catch { res.writeHead(404).end(); }
});
const jwt = `eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.${Buffer.from(JSON.stringify({sub:'00000000-0000-0000-0000-000000000003',exp:Math.floor(Date.now()/1000)+3600})).toString('base64url')}.x`;
(async()=>{
 await new Promise(resolveListen => server.listen(0, '127.0.0.1', resolveListen));
 const origin = `http://127.0.0.1:${server.address().port}`;
 const browser=await chromium.launch({executablePath:browserPath,args:['--no-sandbox','--disable-dev-shm-usage']});
 for (const role of ['student','trainer','owner']) {
  const context=await browser.newContext({viewport:{width:390,height:844}});const page=await context.newPage();const calls=[];let chat=[];let links=[];let exercises=[]; let assessments=role==='student'?[{id:'a1',measured_at:'2026-01-01T00:00:00Z',weight_kg:70,height_cm:175,waist_cm:80}]:[]; let plan=role==='student'?{id:'p',student_id:'00000000-0000-0000-0000-000000000003',title:'Treino sintético',version:1,status:'published'}:null; let items=role==='student'?[{id:'i',exercise_name:'Movimento sintético',exercise_instructions:'',position:1,sets:3,repetitions:'10'}]:[];
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/*', async route => { const url = route.request().url(); if (url.startsWith(origin + '/') || url.startsWith('http://127.0.0.1:7654/')) await route.fallback(); else await route.abort(); });
  await page.route('http://127.0.0.1:7654/**',async route=>{
   const req=route.request(),u=new URL(req.url()),method=req.method();calls.push(`${method} ${u.pathname}${u.pathname === '/auth/v1/recover' ? '?redirect_to=' + u.searchParams.get('redirect_to') : ''}`);
   const user={id:'00000000-0000-0000-0000-000000000003',aud:'authenticated',role:'authenticated',email:'sintetico@example.invalid'};
   let data={};
   if(u.pathname==='/auth/v1/recover') { if(u.searchParams.get('redirect_to') !== origin + '/reset-password') errors.push('unexpected recovery redirect'); data={}; }
   else if(u.pathname==='/rest/v1/rpc/record_student_access') { if(req.postDataJSON().new_status !== 'blocked') errors.push('unexpected access change'); data='synthetic-period'; }
   else if(u.pathname==='/auth/v1/token') data={access_token:jwt,token_type:'bearer',expires_in:3600,refresh_token:'synthetic-refresh',user};
   else if(u.pathname==='/auth/v1/user') data=user;
   else if(u.pathname==='/rest/v1/organization_members') data=(u.searchParams.get('role')||'').startsWith('in.')?[{profile_id:'22222222-0000-0000-0000-000000000002',role:'trainer',profiles:{full_name:'Trainer sintético'}},{profile_id:'33333333-0000-0000-0000-000000000003',role:'student',profiles:{full_name:'Aluno sintético'}}]:u.searchParams.get('select').includes('profiles')?[{profile_id:'00000000-0000-0000-0000-000000000003',profiles:{full_name:'Aluno sintético'}}]:[{organization_id:'10000000-0000-0000-0000-000000000001',role,organizations:{name:'Organização sintética'}}];
   else if(u.pathname==='/rest/v1/trainer_students') { if(method==='POST'){const body=req.postDataJSON();links.push({id:'link',trainer_id:body.trainer_id,student_id:body.student_id,archived_at:null});data={id:'link'};} else data=links; }
   else if(u.pathname==='/rest/v1/access_periods') data=[{id:'a',status:'active',starts_at:'2020-01-01T00:00:00Z',ends_at:null,updated_at:'2020-01-01T00:00:00Z',created_at:'2020-01-01T00:00:00Z'}];
   else if(u.pathname==='/rest/v1/onboarding_progress') data=null;
   else if(u.pathname==='/rest/v1/exercises') { if(method==='POST'){ const body=req.postDataJSON(); exercises.push({id:'e',name:body.name,instructions:body.instructions,archived_at:null}); data={id:'e'}; } else data=exercises; }
   else if(u.pathname==='/rest/v1/rpc/get_training_chat_contacts') data=[{person_id:'00000000-0000-0000-0000-000000000002',full_name:'Contato sintético'}];
   else if(u.pathname==='/rest/v1/rpc/get_training_chat_messages') data=chat;
   else if(u.pathname==='/rest/v1/rpc/send_training_chat_message') { chat.push({id:'m1',sender_id:user.id,body:req.postDataJSON().message_text,created_at:'2026-01-01T00:00:00Z'});data='m1'; }
   else if(u.pathname==='/rest/v1/physical_assessments') data=assessments;
   else if(u.pathname==='/rest/v1/rpc/get_physical_assessments') data=assessments;
   else if(u.pathname==='/rest/v1/rpc/create_physical_assessment') { const body=req.postDataJSON(); assessments.push({id:'a1',measured_at:'2026-01-01T00:00:00Z',weight_kg:body.weight,height_cm:body.height,waist_cm:body.waist});data='a1'; }
   else if(u.pathname==='/rest/v1/training_sessions') { if(method==='POST') data={id:'session',status:'in_progress',completed_at:null}; else if(method==='PATCH') data={id:'session',status:'completed',completed_at:'2026-01-01T00:00:00Z'}; else data=u.searchParams.get('status')==='eq.in_progress'?null:[]; }
   else if(u.pathname==='/rest/v1/training_session_items') data=[];
   else if(u.pathname==='/rest/v1/rpc/get_training_session_summary') data=[{session_id:'s1',plan_title:'Treino sintético',started_at:'2026-01-01T00:00:00Z',completed_at:'2026-01-01T00:00:00Z'}];
   else if(u.pathname==='/rest/v1/training_plans') { if(method==='POST'){const body=req.postDataJSON();plan={id:'p',student_id:body.student_id,title:body.title,version:body.version,status:'draft'};data=plan;} else if(method==='PATCH'){plan={...plan,status:req.postDataJSON().status};data=plan;} else data=plan?[plan]:[]; }
   else if(u.pathname==='/rest/v1/training_plan_items') { if(method==='POST'){const body=req.postDataJSON();items.push({id:'i',exercise_name:'Movimento sintético',exercise_instructions:'',position:body.position,sets:body.sets,repetitions:body.repetitions});data={};} else data=items; }
   else if(u.pathname==='/rest/v1/form_templates') data=[{id:'f',organization_id:'o',title:'Ficha sintética',description:null,state:'published',version:1}];
   else if(u.pathname==='/rest/v1/form_questions') data=[{id:'q',prompt:'Peso sintético',kind:'number',required:true,options:[],position:1}];
   else if(u.pathname==='/rest/v1/anamnesis_submissions') data=method==='GET'?null:{id:'s',status:'draft'};
   else if(u.pathname==='/rest/v1/anamnesis_answers') { if(method==='POST' && req.postDataJSON().response !== -1.25) errors.push('numeric answer was not normalized'); data=[]; }
   else if(['/rest/v1/rpc/get_anamnesis_owner_summary','/rest/v1/rpc/get_anamnesis_trainer_summary'].includes(u.pathname)) data=[{submission_id:'s',student_name:'Aluno sintético',title:'Ficha sintética',version:1,status:'submitted',submitted_at:'2026-01-01T00:00:00Z'}];
   else if(u.pathname.includes('/rpc/get_anamnesis_submission_')) data={student_name:'Aluno sintético',title:'Ficha sintética',version:1,answers:[{question_id:'q',prompt:'Pergunta sintética',question_type:'boolean',response:false}]};
   else { errors.push(`unexpected request ${method} ${u.pathname}`); await route.fulfill({status:500,contentType:'application/json',body:'{}'}); return; }
   await route.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:JSON.stringify(data)});
  });
  try {
   await page.goto(`${origin}/`,{waitUntil:'networkidle'});
   await page.getByText('Entrar na minha conta').click();
   await page.getByLabel('E-mail').fill('sintetico@example.invalid');await page.getByText('Esqueci minha senha').click();await page.getByText('Se o e-mail estiver cadastrado',{exact:false}).waitFor();await page.getByLabel('Senha').fill('synthetic123');await page.getByText('Entrar',{exact:true}).click();
   if(role==='student'){
    await page.getByText('Por onde começar?').waitFor();await page.getByText('Ir para a anamnese').click();await page.getByText('Ficha sintética · versão 1').click();const field=page.getByLabel('Resposta: Peso sintético');await field.fill('-1,25');await page.getByText('Salvar rascunho').click();await page.getByText('Rascunho salvo.',{exact:false}).waitFor();await page.getByText('Voltar aos formulários').click();await page.getByText('Voltar',{exact:true}).click();await page.getByText('Ver meus treinos').click();await page.getByText('Treino sintético · v1 · Publicado').click();await page.getByText('3 séries · 10 repetições').waitFor();await page.getByText('Iniciar treino').click();await page.getByText('Marcar como concluído · Movimento sintético').click();page.once('dialog',d=>d.accept());await page.getByText('Concluir treino').click();await page.getByText('Treino concluído e registrado.').waitFor();await page.getByText('Voltar ao início').click();await page.getByText('Ver minhas avaliações').click();await page.getByText('Peso: 70 kg').waitFor();await page.getByText('Voltar ao início').click();await page.getByText('Mensagens',{exact:true}).click();await page.getByText('Contato sintético').click();await page.getByLabel('Mensagem',{exact:true}).fill('Mensagem sintética');await page.getByText('Enviar mensagem').click();await page.getByText('Mensagem sintética',{exact:true}).waitFor();await page.goto(`${origin}/reset-password`,{waitUntil:'networkidle'});await page.getByLabel('Nova senha',{exact:true}).fill('synthetic456');await page.getByLabel('Confirmar nova senha').fill('synthetic456');await page.getByText('Atualizar senha').click();await page.getByText('Sua senha foi atualizada.').waitFor();
   } else { if(role==='owner')await page.getByText('Ver anamneses enviadas').click();await page.getByText('Aluno sintético · Ficha sintética · v1').click();await page.getByText('Pergunta sintética').waitFor(); await page.getByText('Exercícios',{exact:true}).click(); await page.getByLabel('Nome do exercício').fill('Movimento sintético'); await page.getByText('Adicionar exercício').click(); await page.getByText('Exercício salvo.').waitFor(); await page.getByText('Prescrições',{exact:true}).click();await page.getByText('Aluno sintético',{exact:true}).click();await page.getByLabel('Título da ficha').fill('Treino sintético');await page.getByText('Criar ficha').click();await page.getByText('Movimento sintético',{exact:true}).click();await page.getByLabel('Repetições').fill('10');await page.getByText('Adicionar à ficha').click();await page.getByText('3 séries · 10 repetições').waitFor();page.once('dialog',d=>d.accept());await page.getByText('Publicar ficha').click();await page.getByText('Ficha publicada.').waitFor();await page.getByText('Ver histórico do aluno').click();await page.getByText('Histórico de sessões concluídas.',{exact:false}).waitFor();await page.getByText('Avaliações',{exact:true}).click();await page.getByText('Aluno sintético',{exact:true}).click();await page.getByLabel('Peso (kg)').fill('70');page.once('dialog',d=>d.accept());await page.getByText('Registrar avaliação').click();await page.getByText('Avaliação registrada.').waitFor();if(role==='trainer'){await page.getByText('Mensagens',{exact:true}).click();await page.getByText('Contato sintético').click();await page.getByLabel('Mensagem',{exact:true}).fill('Mensagem sintética');await page.getByText('Enviar mensagem').click();await page.getByText('Mensagem sintética',{exact:true}).waitFor();} await page.getByText('Acessos',{exact:true}).click();await page.getByText('Aluno sintético · 00000000',{exact:true}).click();await page.getByText('Bloqueado',{exact:true}).click();page.once('dialog',d=>d.accept());await page.getByText('Registrar alteração').click();await page.getByText('Alteração de acesso registrada.').waitFor();if(role==='owner'){await page.getByText('Vínculos',{exact:true}).click();await page.getByText('Trainer sintético · 22222222').click();await page.getByText('Aluno sintético · 33333333').click();page.once('dialog',d=>d.accept());await page.getByText('Criar vínculo').click();await page.getByText('Vínculo registrado.').waitFor();} }
   assert.deepEqual(errors, []); console.log(`${role}: PASS (${calls.length} requisições sintéticas)`);
  } catch(e){console.error(`${role}: FAIL ${e.message}; requests: ${calls.join(', ')}`);process.exitCode=1;}
  await context.close();
 }
 await browser.close(); await new Promise(resolveClose => server.close(resolveClose)); rmSync(outDir, { recursive: true, force: true });
})().catch(e=>{console.error(e); server.close(); rmSync(outDir, { recursive: true, force: true }); process.exitCode=1});
