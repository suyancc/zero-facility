"""Capture actual exported Godot models in an isolated browser. No user's tabs.
Run after building exports/web, then normalize and rebuild to include the new PNGs.
"""
import asyncio,base64,functools,threading
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1]
class Quiet(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
async def main():
 dest=ROOT/'assets/ui/items';dest.mkdir(parents=True,exist_ok=True)
 server=ThreadingHTTPServer(('127.0.0.1',8782),functools.partial(Quiet,directory=str(ROOT/'exports/web')))
 threading.Thread(target=server.serve_forever,daemon=True).start()
 try:
  async with async_playwright() as pw:
   exe=next(str(p) for p in [Path(r'C:\Program Files\Google\Chrome\Application\chrome.exe'),Path(r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe')] if p.exists())
   browser=await pw.chromium.launch(executable_path=exe,headless=True)
   try:
    page=await browser.new_page(viewport={'width':1280,'height':800});errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    await page.goto('http://127.0.0.1:8782/?qa=1&bake_items=1',timeout=90000)
    await page.wait_for_function('window.__gravityCourierQA?.state===0',timeout=90000)
    for i,kind in enumerate(['smoke','jammer','pick','decoy']):
     if i:
      q=await page.evaluate('window.__gravityCourierQA');box=await page.locator('canvas').bounding_box();x,y=q['catalog_centers'][i];vw,vh=q['viewport_size']
      await page.mouse.click(box['x']+x*box['width']/vw,box['y']+y*box['height']/vh)
     await page.wait_for_function('(kind)=>window.__equipmentThumbnail?.kind===kind',arg=kind,timeout=45000)
     result=await page.evaluate('window.__equipmentThumbnail');data=base64.b64decode(result['png'])
     (dest/(kind+'.png')).write_bytes(data);print('THUMBNAIL',kind,len(data),flush=True)
    assert not errors,errors
   finally:await browser.close()
 finally:server.shutdown();server.server_close()
if __name__=='__main__':asyncio.run(main())

