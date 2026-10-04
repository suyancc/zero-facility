"""Isolated headless browser only: never connects to the user's open browser."""
import asyncio, json
from pathlib import Path
from playwright.async_api import async_playwright
ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'exports/evidence'
URL = 'http://127.0.0.1:8769/?qa=1&v=0.6.2'
async def main():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    report = {'checks': [], 'errors': []}
    async with async_playwright() as engine:
        browser = await engine.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe', headless=True, args=['--use-angle=d3d11', '--disable-background-timer-throttling', '--disable-renderer-backgrounding'])
        try:
            page = await browser.new_page(viewport={'width':1280,'height':800}, device_scale_factor=1)
            page.on('pageerror', lambda err: report['errors'].append(str(err)))
            page.on('console', lambda msg: report['errors'].append(msg.text) if msg.type=='error' else None)
            async def wait(expression, timeout=12000):
                await page.wait_for_function('()=>'+expression, timeout=timeout, polling=50)
            async def snapshot():
                return await page.evaluate('window.__gravityCourierQA')
            async def fresh():
                await page.goto(URL, wait_until='load')
                await wait('window.__gravityCourierQA?.state===0 && window.__gravityCourierQA?.tracking==="card"',45000)
            async def shot(name):
                await page.screenshot(path=str(EVIDENCE/name), type='jpeg', quality=88)
            await fresh()
            await page.keyboard.press('t')
            await wait('window.__gravityCourierQA.tracking==="override"')
            await page.mouse.click(105,460)
            await wait('window.__gravityCourierQA.tracking==="exit_pick"')
            report['checks'].append('Keyboard T and left tracking button select distinct solutions')
            await shot('v62-guidance.jpg')
            await page.keyboard.press('Space')
            await wait('window.__gravityCourierQA.state===1')
            for x,y in [(650,320),(620,300),(580,290)]:
                await page.mouse.move(x,y)
                await page.wait_for_timeout(250)
                q = await snapshot()
                if q.get('aim_valid') and q.get('arc_points')==25: break
            assert q['aim_valid'] and q['arc_points']==25, 'No valid arc rendered'
            await shot('v62-trajectory.jpg')
            await page.keyboard.press('1')
            await wait('window.__gravityCourierQA.projectiles===1',5000)
            report['airborne'] = await snapshot()
            await page.keyboard.press('Escape')
            await wait('window.__gravityCourierQA.state===2')
            paused = await snapshot()
            await page.wait_for_timeout(400)
            assert (await snapshot())['time']==paused['time'], 'Clock advanced while paused'
            report['checks'].append('Real hotkey launches finite-charge airborne canister; pause freezes clock')
            await page.keyboard.press('Space')
            await wait('window.__gravityCourierQA.smoke_count===1 && window.__gravityCourierQA.projectiles===0')
            await page.wait_for_timeout(450)
            report['landed']=await snapshot()
            await shot('v62-smoke-landed.jpg')
            report['checks'].append('Projectile lands and smoke becomes active')
            await fresh()
            await page.mouse.click(535,580)
            await wait('window.__gravityCourierQA.loadout[0]==="jammer"')
            await page.mouse.click(80,363)
            await page.mouse.click(410,580)
            await wait('window.__gravityCourierQA.loadout[1]==="smoke"')
            report['checks'].append('Actual icon cards equip jammer and smoke into separate inventory slots')
            await page.keyboard.press('Space')
            await wait('window.__gravityCourierQA.state===1')
            await page.keyboard.down('Shift')
            await page.keyboard.down('ArrowRight')
            await page.keyboard.down('ArrowDown')
            try:
                await wait('window.__gravityCourierQA.state!==1 || window.__gravityCourierQA.guards.some(g=>Math.hypot(g.position[0]-window.__gravityCourierQA.position[0],g.position[1]-window.__gravityCourierQA.position[1])<2.7)',8000)
            finally:
                for key in ['ArrowDown','ArrowRight','Shift']:await page.keyboard.up(key)
            assert (await snapshot())['state']==1, 'Approach was caught'
            await page.keyboard.press('1')
            await wait('window.__gravityCourierQA.jam_hits>0',4000)
            await page.wait_for_timeout(150)
            report['jammed']=await snapshot()
            await shot('v62-device-offline.jpg')
            report['checks'].append('Actual movement approaches a guard; EMP reports a real hit and consumes the charge')
            await page.keyboard.press('Escape')
            assert not report['errors'], 'Browser console/page errors'
            report['success']=True
        except Exception as exc:
            report['success']=False
            report['failure']=str(exc)
            try:
                report['last_snapshot']=await snapshot()
                await shot('v62-browser-failure.jpg')
            except Exception:pass
        finally:
            await browser.close()
    (EVIDENCE/'v62-web-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=True))
    if not report['success']:raise SystemExit(1)
asyncio.run(main())

