"""Fresh isolated Edge, real input, no user browser/save access."""
import asyncio,json,math
from collections import deque
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1];E=ROOT/'exports/evidence'
async def main():
 E.mkdir(parents=True,exist_ok=True);r={'checks':[],'errors':[],'briefs':{}}
 async with async_playwright() as pw:
  browser=await pw.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',headless=True,args=['--use-angle=d3d11'])
  try:
   page=await browser.new_page(viewport={'width':1280,'height':800},device_scale_factor=1)
   page.on('pageerror',lambda e:r['errors'].append(str(e)))
   page.on('console',lambda m:r['errors'].append(m.text) if m.type=='error' else None)
   async def wait(e,t=45000):await page.wait_for_function('()=>'+e,timeout=t,polling=30)
   async def snap():return await page.evaluate('window.__gravityCourierQA')
   for stage in [1]:
    await page.goto(f'http://127.0.0.1:8769/?qa=1&stage={stage}&v=0.6.6')
    await wait(f'window.__gravityCourierQA?.stage==={stage} && window.__gravityCourierQA?.state===0')
    q=await snap();assert q['variant_title'] in q['ready_heading'];assert '出口' in q['brief']
    r['briefs'][stage]={'heading':q['ready_heading'],'brief':q['brief'],'tracking':q['tracking_name']}
    if stage==1:
     await page.wait_for_timeout(350);await page.screenshot(path=str(E/f'v66-objective-{stage}.jpg'),type='jpeg',quality=90)
   r['checks'].append('READY remains calm and retains current mission information')
   await page.goto('http://127.0.0.1:8769/?qa=1&stage=1&v=0.6.6')
   await wait('window.__gravityCourierQA?.stage===1 && window.__gravityCourierQA?.state===0')
   q=await snap();await page.mouse.click(*q['catalog_centers'][1]);await wait('window.__gravityCourierQA.loadout[0]==="jammer"')
   r['checks'].append('Model cards remain clickable after dynamic brief layout change')
   await page.keyboard.press('Space');await wait('window.__gravityCourierQA.state===1')
   # Actual E away from every interactable must not start phantom operation audio.
   await page.keyboard.down('e');await page.wait_for_timeout(350);q=await snap();assert not q['operation_playing'] and q['operation_audio']==''
   await page.keyboard.up('e');await page.keyboard.press('Escape');await wait('window.__gravityCourierQA.state===2')
   assert not (await snap())['operation_playing'];r['checks'].append('Out-of-range E and pause do not start a phantom work loop')
   await page.keyboard.press('r');await wait('window.__gravityCourierQA.state===0');q=await snap()
   assert q['variant_title']=='多路突破' and not q['operation_playing'];r['checks'].append('Retry retains objective and clears operation channel')
   await page.keyboard.press('Space');await wait('window.__gravityCourierQA.state===1')
   q=await snap();target=next(i['at'] for i in q['items'] if i['kind']=='card')
   def cell(at):return (round(at[0]/1.3+9),round(at[1]/1.3+7))
   start=cell(q['position']);goal=cell(target);blocked={tuple(c) for c in q['blocked']};todo=deque([start]);previous={start:None}
   while todo and goal not in previous:
    x,y=todo.popleft()
    for nxt in [(x+1,y),(x-1,y),(x,y+1),(x,y-1)]:
     if 0<=nxt[0]<19 and 0<=nxt[1]<15 and nxt not in blocked and nxt not in previous:previous[nxt]=(x,y);todo.append(nxt)
   assert goal in previous
   nodes=[];c=goal
   while c!=start:nodes.append(c);c=previous[c]
   path=[((x-9)*1.3,(y-7)*1.3) for x,y in reversed(nodes)];held=set();steps=0
   while path and steps<1600:
    q=await snap();assert q['state']==1,'Navigation was caught'
    mode=q['tension_mode']
    if mode=='chase' and q['charges']['jammer']>0 and any(math.dist(g['position'],q['position'])<2.9 for g in q['guards']):
     await page.keyboard.press('1');r['countermeasure']='Actual EMP hotkey during chase'

    if mode not in r.setdefault('moods',{}):
     r['moods'][mode]={'intensity':q['tension_intensity'],'bpm':q['tension_bpm'],'weights':q['music_weights'],'beats':q['heartbeat_count']}
     if mode in ['suspect','chase','recovery']:
      await page.screenshot(path=str(E/f'v66-{mode}.jpg'),type='jpeg',quality=90)
    if mode=='chase' and q['tension_intensity']>.8 and not r.get('peak'):
     r['peak']={'intensity':q['tension_intensity'],'bpm':q['tension_bpm'],'weights':q['music_weights']}
     await page.screenshot(path=str(E/'v66-chase-peak.jpg'),type='jpeg',quality=90)
    if mode=='recovery' and 'chase' in r.get('moods',{}):break
    pos=q['position'];dest=path[0]
    if math.dist(pos,dest)<(.60 if len(path)==1 else .26):path.pop(0);continue
    force=[(dest[j]-pos[j])*5.5-q['velocity'][j]*.35 for j in range(2)]
    horizontal=sum(force[j]*q['right_axis'][j] for j in range(2));vertical=-sum(force[j]*q['forward_axis'][j] for j in range(2))
    keys=set()
    if abs(horizontal)>.30:keys.add('ArrowRight' if horizontal>0 else 'ArrowLeft')
    if abs(vertical)>.30:keys.add('ArrowDown' if vertical>0 else 'ArrowUp')
    for key in held-keys:await page.keyboard.up(key)
    for key in keys-held:await page.keyboard.down(key)
    held=keys;await page.wait_for_timeout(65);steps+=1
   for key in held:await page.keyboard.up(key)
   assert 'chase' in r.get('moods',{}) and 'recovery' in r.get('moods',{}),'Missing actual chase/recovery transition'
   r['checks'].append('Actual recognition, chase and EMP escape drive suspicion/chase/recovery music and heartbeat')
   q=await snap();assert q['heartbeat_count']>0 and q['music_weights']['recovery']>=0
   await page.keyboard.press('Escape');await wait('window.__gravityCourierQA.state===2')
   frozen=await snap();await page.wait_for_timeout(500);later=await snap()
   assert later['tension_phase']==frozen['tension_phase'] and later['heartbeat_count']==frozen['heartbeat_count']
   r['checks'].append('Real pause freezes shared heartbeat phase and audio trigger count')
   await page.mouse.click(1130,47);await page.wait_for_timeout(300)
   await page.screenshot(path=str(E/'v66-settings.jpg'),type='jpeg',quality=90)
   await page.mouse.click(420,279);await page.keyboard.press('Home')
   await page.mouse.click(420,338);await page.keyboard.press('Home')
   await page.mouse.click(841,373)
   await wait('window.__gravityCourierQA.music_volume===0 && window.__gravityCourierQA.heartbeat_volume===0 && !window.__gravityCourierQA.edge_enabled')
   await page.mouse.click(640,550);await wait('window.__gravityCourierQA.state===1')
   before=await snap();await page.wait_for_timeout(700);after=await snap()
   assert not after['edge_visible'] and before['heartbeat_count']==after['heartbeat_count']
   r['checks'].append('Actual settings sliders and edge toggle independently silence music/heartbeat and remove edge effect')
   await page.keyboard.press('Escape')
   assert not r['errors'];r['success']=True
  except Exception as e:
   r['success']=False;r['failure']=str(e)
   try:await page.screenshot(path=str(E/'v66-failure.jpg'))
   except Exception:pass
  finally:await browser.close()
 (E/'v66-web-report.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(r,ensure_ascii=True))
 if not r['success']:raise SystemExit(1)
asyncio.run(main())

