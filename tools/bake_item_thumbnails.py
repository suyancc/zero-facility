"""Capture original Godot models in a separate headless browser, not user's session.
Build Web, serve exports/web on 8769, then run with Windows Python + Playwright.
Images retain alpha; no external model/image generators or screenshot cropping.
"""
import asyncio,base64
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1]
async def main():
 dest=ROOT/'assets/ui/items';dest.mkdir(parents=True,exist_ok=True)
 async with async_playwright() as pw:
  browser=await pw.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',headless=True,args=['--use-angle=d3d11'])
  try:
   page=await browser.new_page(viewport={'width':1280,'height':800});errors=[]
   page.on('pageerror',lambda e:errors.append(str(e)))
   await page.goto('http://127.0.0.1:8769/?qa=1&bake_items=1')
   for kind,x in [('smoke',410),('jammer',535),('pick',660),('decoy',785)]:
    if kind!='smoke':await page.mouse.click(x,580)
    await page.wait_for_function('(kind)=>window.__equipmentThumbnail?.kind===kind',arg=kind,timeout=45000)
    result=await page.evaluate('window.__equipmentThumbnail');data=base64.b64decode(result['png'])
    (dest/(kind+'.png')).write_bytes(data);print('THUMBNAIL',kind,len(data))
   assert not errors,errors
  finally:await browser.close()
asyncio.run(main())
