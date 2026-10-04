"""Independent fresh headless Edge; never touches user's browser or save."""
import asyncio,json
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1];E=ROOT/'exports/evidence'
async def main():
 E.mkdir(parents=True,exist_ok=True);report={'checks':[],'errors':[]}
 async with async_playwright() as pw:
  browser=await pw.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',headless=True,args=['--use-angle=d3d11','--disable-background-timer-throttling'])
  try:
   p=await browser.new_page(viewport={'width':1280,'height':800},device_scale_factor=1)
   p.on('pageerror',lambda e:report['errors'].append(str(e)))
   p.on('console',lambda m:report['errors'].append(m.text) if m.type=='error' else None)
   async def wait(e,timeout=12000):await p.wait_for_function('()=>'+e,timeout=timeout,polling=50)
   async def snap():return await p.evaluate('window.__gravityCourierQA')
   async def shot(name):await p.screenshot(path=str(E/name),type='jpeg',quality=90)
   await p.goto('http://127.0.0.1:8769/?qa=1&v=0.6.4',wait_until='load')
   await wait('window.__gravityCourierQA?.state===0',45000)
   q=await snap();assert q['preview_kind']=='smoke' and q['preview_visible'] and not q['task_playing']
   await p.wait_for_timeout(350);await shot('v64-ready-smoke.jpg');report['checks'].append('Initial READY selects and renders equipped smoke model without autoplay task sound')
   for kind,x in [('jammer',535),('pick',660),('decoy',785),('smoke',410)]:
    await p.mouse.click(x,580);await wait(f'window.__gravityCourierQA.preview_kind==="{kind}" && window.__gravityCourierQA.loadout[0]==="{kind}"')
    await p.wait_for_timeout(350);await shot('v64-ready-'+kind+'.jpg')
   report['checks'].append('Actual clicks select all four corresponding 3D models, preserving unique equipped slots')
   await p.mouse.click(80,363);await wait('window.__gravityCourierQA.preview_slot===1')
   await p.mouse.click(535,580);await wait('window.__gravityCourierQA.preview_kind==="jammer" && window.__gravityCourierQA.loadout[1]==="jammer"')
   report['checks'].append('Editing slot two updates model, slot badge and unique loadout')
   await shot('v64-ready-slot2.jpg')
   await p.keyboard.press('Space');await wait('window.__gravityCourierQA.state===1 && !window.__gravityCourierQA.preview_visible')
   report['checks'].append('Preview is hidden and disabled in gameplay')
   await shot('v64-world.jpg')
   await p.keyboard.press('Escape');await wait('window.__gravityCourierQA.state===2 && window.__gravityCourierQA.task_paused')
   q=await snap();await p.wait_for_timeout(400);assert (await snap())['time']==q['time']
   await p.keyboard.press('Space');await wait('window.__gravityCourierQA.state===1 && !window.__gravityCourierQA.task_paused')
   report['checks'].append('Real pause and resume include dedicated task audio channel')
   await p.keyboard.press('m');await wait('window.__gravityCourierQA.muted')
   await p.keyboard.press('m');await wait('!window.__gravityCourierQA.muted')
   await p.keyboard.press('r');await wait('window.__gravityCourierQA.state===0 && window.__gravityCourierQA.preview_visible && window.__gravityCourierQA.task_audio===""')
   report['checks'].append('Mute toggle and retry leave no stale task cue')
   report['snapshot']=await snap();assert not report['errors'];report['success']=True
  except Exception as e:
   report['success']=False;report['failure']=str(e)
   try:report['last_snapshot']=await snap();await shot('v64-browser-failure.jpg')
   except Exception:pass
  finally:await browser.close()
 (E/'v64-web-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps(report,ensure_ascii=True))
 if not report['success']:raise SystemExit(1)
asyncio.run(main())
