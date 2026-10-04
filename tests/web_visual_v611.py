"""Independent browser UI + paired warm-frame measurement. No access to user tabs."""
import asyncio,functools,json,threading
from pathlib import Path
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1]
class Quiet(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
async def main():
 server=ThreadingHTTPServer(('127.0.0.1',8781),functools.partial(Quiet,directory=str(ROOT)))
 threading.Thread(target=server.serve_forever,daemon=True).start()
 r={'checks':[],'errors':[],'performance':[],'sizes':[]}
 try:
  async with async_playwright() as pw:
   exe=next(str(x) for x in [Path(r'C:\Program Files\Google\Chrome\Application\chrome.exe'),Path(r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe')] if x.exists())
   b=await pw.chromium.launch(executable_path=exe,headless=True)
   try:
    for version,folder in [('0.6.10','exports/perf-v610'),('0.6.11','web')]:
     p=await b.new_page(viewport={'width':1280,'height':800})
     p.on('pageerror',lambda e:r['errors'].append(str(e)))
     p.on('console',lambda m:r['errors'].append(m.text) if m.type=='error' else None)
     await p.goto(f'http://127.0.0.1:8781/{folder}/?qa=1&stage=1',timeout=90000)
     await p.wait_for_function('window.__gravityCourierQA?.state===0',timeout=90000)
     await p.keyboard.press('Space');await p.wait_for_timeout(2500)
     metrics=await p.evaluate('''()=>new Promise(resolve=>{let values=[],last=performance.now(),end=last+6000;function f(t){values.push(t-last);last=t;if(t<end){requestAnimationFrame(f);return;}values.sort((a,b)=>a-b);resolve({n:values.length,mean_ms:values.reduce((a,b)=>a+b,0)/values.length,median_ms:values[Math.floor(values.length/2)],p95_ms:values[Math.floor((values.length-1)*.95)],max_ms:values.at(-1),snapshot:window.__gravityCourierQA});}requestAnimationFrame(f);})''')
     q=metrics.pop('snapshot');metrics.update(version=version,alerts=q['alerts'],risk=q['risk'],fps=q['fps'],draw_calls=q.get('draw_calls'),pose_cpu_us=q.get('human_pose_cpu_mean_usec'));r['performance'].append(metrics)
     # A second sample moves the character via real keyboard input near the safe spawn.
     async def motion_sample():
      return await p.evaluate('''()=>new Promise(resolve=>{let v=[],last=performance.now(),end=last+6000;function f(t){v.push(t-last);last=t;if(t<end){requestAnimationFrame(f);return}v.sort((a,b)=>a-b);resolve({n:v.length,mean_ms:v.reduce((a,b)=>a+b,0)/v.length,p95_ms:v[Math.floor((v.length-1)*.95)],snapshot:window.__gravityCourierQA});}requestAnimationFrame(f)})''')
     sampler=asyncio.create_task(motion_sample())
     for i in range(12):
      key='ArrowRight' if i%2==0 else 'ArrowLeft';await p.keyboard.down(key);await p.wait_for_timeout(500);await p.keyboard.up(key)
     moving=await sampler;mq=moving.pop('snapshot');moving.update(pose_cpu_us=mq.get('human_pose_cpu_mean_usec'),risk=mq['risk'],state=mq['state']);metrics['motion']=moving
     await p.close()
    for width,height in [(1280,800),(1600,900),(1024,768)]:
     p=await b.new_page(viewport={'width':width,'height':height})
     p.on('pageerror',lambda e:r['errors'].append(str(e)))
     await p.goto('http://127.0.0.1:8781/web/?qa=1&stage=1',timeout=90000)
     await p.wait_for_function('window.__gravityCourierQA?.state===0',timeout=90000)
     async def q():return await p.evaluate('window.__gravityCourierQA')
     async def click(point,s):
      box=await p.locator('canvas').bounding_box();vw,vh=s['viewport_size']
      assert 0<point[0]<vw and 0<point[1]<vh,point
      await p.mouse.click(box['x']+point[0]*box['width']/vw,box['y']+point[1]*box['height']/vh)
     s=await q();assert s['showcase_enabled'] and s['version']=='0.6.11'
     if width==1280:await p.screenshot(path=str(ROOT/'exports/evidence/v611-ready.jpg'),type='jpeg',quality=90)
     await click(s['settings_button_center'],s)
     await p.wait_for_function('window.__gravityCourierQA.settings_visible')
     s=await q();await click(s['settings_close_center'],s)
     await p.wait_for_function('!window.__gravityCourierQA.settings_visible && window.__gravityCourierQA.state===0')
     for index,kind in enumerate(['smoke','jammer','pick','decoy']):
      s=await q();await click(s['catalog_centers'][index],s)
      await p.wait_for_function('(k)=>window.__gravityCourierQA.preview_kind===k',arg=kind)
     s=await q();await click(s['inventory_centers'][1],s)
     await p.wait_for_function('window.__gravityCourierQA.preview_slot===1')
     s=await q();await click(s['catalog_centers'][0],s)
     await p.wait_for_function('window.__gravityCourierQA.loadout[1]==="smoke"')
     s=await q();assert len(set(s['loadout']))==2
     await p.keyboard.press('Space');await p.wait_for_function('window.__gravityCourierQA.state===1 && !window.__gravityCourierQA.showcase_enabled')
     await p.keyboard.press('Escape');await p.wait_for_function('window.__gravityCourierQA.state===2')
     await p.keyboard.press('r');await p.wait_for_function('window.__gravityCourierQA.state===0 && window.__gravityCourierQA.showcase_enabled')
     r['sizes'].append([width,height]);await p.close()
    r['checks']=['Ready character, four gear cards and second slot work at three desktop sizes','Starting disables character showcase; pause and retry restore expected layouts','Paired calm gameplay frame timings collected with music enabled']
    assert not r['errors'],r['errors'];r['success']=True
   finally:await b.close()
 except Exception as e:r.update(success=False,failure=str(e))
 finally:server.shutdown();server.server_close()
 (ROOT/'exports/evidence/v611-visual-report.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps(r,ensure_ascii=True),flush=True)
 if not r.get('success'):raise SystemExit(1)
if __name__=='__main__':asyncio.run(main())

