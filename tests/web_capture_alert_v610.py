"""Actual keyboard-driven warning/chase screenshot; isolated context, no QA mutation."""
import asyncio,functools,json,shutil,threading
from pathlib import Path
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from playwright.async_api import async_playwright,TimeoutError as PlaywrightTimeoutError
ROOT=Path(__file__).resolve().parents[1]
class Quiet(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
async def main():
 out=ROOT/'exports/evidence';r={'errors':[]}
 server=ThreadingHTTPServer(('127.0.0.1',8783),functools.partial(Quiet,directory=str(ROOT/'web')))
 threading.Thread(target=server.serve_forever,daemon=True).start()
 try:
  async with async_playwright() as pw:
   exe=next(str(x) for x in [Path(r'C:\Program Files\Google\Chrome\Application\chrome.exe'),Path(r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe')] if x.exists())
   b=await pw.chromium.launch(executable_path=exe,headless=True)
   try:
    p=await b.new_page(viewport={'width':1280,'height':800});p.on('pageerror',lambda e:r['errors'].append(str(e)))
    await p.goto('http://127.0.0.1:8783/?qa=1&stage=1',timeout=90000)
    await p.wait_for_function('window.__gravityCourierQA?.state===0',timeout=90000)
    await p.keyboard.press('Space');await p.wait_for_function('window.__gravityCourierQA.state===1')
    for key in ['Shift','ArrowRight','ArrowDown']:await p.keyboard.down(key)
    try:await p.wait_for_function('window.__gravityCourierQA.detection_count>0 || window.__gravityCourierQA.state!==1',timeout=15000)
    finally:
     for key in ['Shift','ArrowRight','ArrowDown']:await p.keyboard.up(key)
    q=await p.evaluate('window.__gravityCourierQA');assert q['state']==1 and q['detection_count']>0
    await p.screenshot(path=str(out/'v610-warning.jpg'),type='jpeg',quality=90)
    shutil.copy2(out/'v610-warning.jpg',out/'v610-alert.jpg');r['captured_state']='warning';r['snapshot']=q
    try:
     await p.wait_for_function('window.__gravityCourierQA.guards.some(g=>g.mode==="追捕") || window.__gravityCourierQA.state!==1',timeout=6000)
     q=await p.evaluate('window.__gravityCourierQA')
     if q['state']==1 and any(g['mode']=='追捕' for g in q['guards']):
      await p.screenshot(path=str(out/'v610-chase.jpg'),type='jpeg',quality=90)
      if (await p.evaluate('window.__gravityCourierQA.state'))==1:
       shutil.copy2(out/'v610-chase.jpg',out/'v610-alert.jpg');r['captured_state']='chase';r['snapshot']=q
    except PlaywrightTimeoutError:pass
    assert not r['errors'];r['success']=True
   finally:await b.close()
 finally:server.shutdown();server.server_close()
 (out/'v610-alert.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps({'success':r['success'],'captured_state':r['captured_state'],'errors':r['errors']}),flush=True)
if __name__=='__main__':asyncio.run(main())
