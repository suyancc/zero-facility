import asyncio,json,functools,threading,os
from pathlib import Path
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1];E=ROOT/'exports/evidence';E.mkdir(parents=True,exist_ok=True)
async def main():
 r={'errors':[]}
 async with async_playwright() as p:
  b=await p.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',headless=True,args=['--use-angle=d3d11']);page=await b.new_page(viewport={'width':1600,'height':900});page.on('pageerror',lambda e:r['errors'].append(str(e)))
  await page.goto('http://127.0.0.1:8784/?qa=1&stage=1');await page.wait_for_function('window.__gravityCourierQA?.state===0',timeout=90000);await page.wait_for_timeout(800);await page.screenshot(path=str(E/'v611-human-ready.jpg'),type='jpeg',quality=94)
  await page.keyboard.press('Space');await page.wait_for_function('window.__gravityCourierQA.state===1');await page.wait_for_timeout(500);await page.screenshot(path=str(E/'v611-human-gameplay.jpg'),type='jpeg',quality=94)
  for kind,keys in [('walk',['ArrowRight']),('run',['Shift','ArrowRight']),('sneak',['Control','ArrowLeft'])]:
   for key in keys:await page.keyboard.down(key)
   await page.wait_for_timeout(250);await page.screenshot(path=str(E/f'v611-human-{kind}.jpg'),type='jpeg',quality=94)
   for key in keys:await page.keyboard.up(key)
  await page.keyboard.down('Tab');await page.wait_for_timeout(900);await page.screenshot(path=str(E/'v611-human-overview.jpg'),type='jpeg',quality=94)
  await page.keyboard.up('Tab')
  r['snapshot']=await page.evaluate('window.__gravityCourierQA');assert not r['errors'];r['success']=True;await b.close()
 (E/'v611-human-capture.json').write_text(json.dumps(r,indent=2));print(json.dumps(r))
class Quiet(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',8784),functools.partial(Quiet,directory=str(ROOT/os.environ.get('GAME_WEB_DIR','exports/v611-audio-game-web'))));threading.Thread(target=server.serve_forever,daemon=True).start()
try:asyncio.run(main())
finally:server.shutdown()

