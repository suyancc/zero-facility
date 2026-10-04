"""New independent Chrome context; never attaches to existing tabs or saves."""
import asyncio,functools,json,sys,threading
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1]
class Quiet(SimpleHTTPRequestHandler):
    def log_message(self,*args):pass
async def main():
    output=ROOT/'exports/evidence';output.mkdir(parents=True,exist_ok=True)
    remote=sys.argv[1] if len(sys.argv)>1 else None
    server=None
    if not remote:
        server=ThreadingHTTPServer(('127.0.0.1',8774),functools.partial(Quiet,directory=str(ROOT/'web')))
        threading.Thread(target=server.serve_forever,daemon=True).start()
    url=remote or 'http://127.0.0.1:8774/'
    result={'url':url,'errors':[],'checks':[]}
    try:
        async with async_playwright() as pw:
            exe=next(str(p) for p in [Path(r'C:\Program Files\Google\Chrome\Application\chrome.exe'),Path(r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe')] if p.exists())
            browser=await pw.chromium.launch(executable_path=exe,headless=True)
            try:
                page=await browser.new_page(viewport={'width':1280,'height':800})
                page.on('pageerror',lambda e:result['errors'].append(str(e)))
                page.on('console',lambda m:result['errors'].append(m.text) if m.type=='error' else None)
                response=await page.goto(url+'?qa=1&stage=1',timeout=120000)
                assert response.status==200
                await page.wait_for_function('window.__gravityCourierQA?.state===0',timeout=120000)
                result['checks'].append('HTTPS/HTTP entry and WebGL/Wasm/PCK reached READY')
                await page.screenshot(path=str(output/'pages-ready.jpg'),type='jpeg',quality=88)
                await page.keyboard.press('Space')
                await page.wait_for_function('window.__gravityCourierQA?.state===1',timeout=20000)
                before=await page.evaluate('window.__gravityCourierQA.position')
                await page.keyboard.down('ArrowRight');await page.wait_for_timeout(650);await page.keyboard.up('ArrowRight')
                await page.wait_for_timeout(400)
                after=await page.evaluate('window.__gravityCourierQA.position')
                assert sum((a-b)**2 for a,b in zip(after,before))>.01,(before,after)
                result['checks'].append('Real keyboard input starts game and moves player')
                await page.screenshot(path=str(output/'pages-playing.jpg'),type='jpeg',quality=88)
                await page.keyboard.down('Tab');await page.wait_for_timeout(1200)
                await page.screenshot(path=str(output/'pages-overview.jpg'),type='jpeg',quality=88)
                await page.keyboard.up('Tab');await page.keyboard.press('Escape')
                await page.wait_for_function('window.__gravityCourierQA?.state===2',timeout=20000)
                result['checks'].append('Pause responds')
                result['snapshot']=await page.evaluate('({state:window.__gravityCourierQA.state,fps:window.__gravityCourierQA.fps,stage:window.__gravityCourierQA.stage})')
                assert not result['errors'],result['errors']
                result['success']=True
            finally:await browser.close()
    except Exception as e:result.update(success=False,failure=str(e))
    finally:
        if server:server.shutdown();server.server_close()
    (output/('pages-live-smoke.json' if remote else 'pages-local-smoke.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=True),flush=True)
    if not result.get('success'):raise SystemExit(1)
asyncio.run(main())
