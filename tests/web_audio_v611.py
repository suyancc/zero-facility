"""WebAudio analyser measures rendered output, not just AudioStreamPlayer flags.
Independent Edge context; no mic, system loopback or user's browser access.
"""
import os,asyncio,json,math
from pathlib import Path
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1];E=ROOT/'exports/evidence'
TAP=r'''(()=>{
 const connect=AudioNode.prototype.connect;const taps=new WeakMap();window.__mixTaps=[];
 AudioNode.prototype.connect=function(dest,...args){
  if(dest instanceof AudioDestinationNode){
   let a=taps.get(this.context);
   if(!a){a=this.context.createAnalyser();a.fftSize=4096;taps.set(this.context,a);window.__mixTaps.push(a);connect.call(a,dest);}
   connect.call(this,a,...args);return dest;
  }
  return connect.call(this,dest,...args);
 };
 window.measureOutput=async function(ms){
  let sum=0,n=0,peak=0;const a=window.__mixTaps[0];if(!a)throw Error('No output analyser attached');
  const x=new Float32Array(a.fftSize);const end=performance.now()+ms;
  while(performance.now()<end){a.getFloatTimeDomainData(x);for(const v of x){sum+=v*v;n++;peak=Math.max(peak,Math.abs(v));}await new Promise(r=>setTimeout(r,20));}
  return {rms_dbfs:20*Math.log10(Math.max(Math.sqrt(sum/n),1e-12)),peak_dbfs:20*Math.log10(Math.max(peak,1e-12)),context:a.context.state,samples:n};
 };
})();'''
async def main():
 E.mkdir(parents=True,exist_ok=True);r={'checks':[],'errors':[]}
 async with async_playwright() as pw:
  browser=await pw.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',headless=True,args=['--use-angle=d3d11'])
  try:
   page=await browser.new_page(viewport={'width':1280,'height':800},device_scale_factor=1);await page.add_init_script(TAP)
   await page.add_init_script("window.__sourceStarts=0;const originalStart=AudioBufferSourceNode.prototype.start;AudioBufferSourceNode.prototype.start=function(...a){window.__sourceStarts++;return originalStart.apply(this,a);};")
   page.on('pageerror',lambda e:r['errors'].append(str(e)));page.on('console',lambda m:r['errors'].append(m.text) if m.type=='error' else None)
   async def wait(e,t=45000):await page.wait_for_function('()=>'+e,timeout=t,polling=30)
   async def q():return await page.evaluate('window.__gravityCourierQA')
   await page.goto('http://127.0.0.1:8782/?qa=1&stage=1&v=0.6.8');await wait('window.__gravityCourierQA?.state===0')
   s=await q();await page.mouse.click(*s['catalog_centers'][1]);await page.wait_for_timeout(1200)
   starts=await page.evaluate('window.__sourceStarts')
   r['calm_output']=await page.evaluate('measureOutput(3000)')
   r['calm_source_starts']=await page.evaluate('window.__sourceStarts')-starts
   assert r['calm_source_starts']<=15,r['calm_source_starts']
   r['checks'].append('Steady music does not repeatedly restart WebAudio sources')
   assert r['calm_output']['context']=='running' and -43<r['calm_output']['rms_dbfs']<-20,r['calm_output']
   r['checks'].append('Stationary READY has actual audible-range background PCM at default levels')
   await page.keyboard.press('m');await wait('window.__gravityCourierQA.muted');await page.wait_for_timeout(200)
   r['muted_output']=await page.evaluate('measureOutput(500)');assert r['muted_output']['peak_dbfs']<-80
   await page.keyboard.press('m');await wait('!window.__gravityCourierQA.muted')
   r['checks'].append('Master mute silences actual WebAudio output')
   await page.keyboard.press('Space');await wait('window.__gravityCourierQA.state===1')
   await page.keyboard.down('Shift');await page.keyboard.down('ArrowRight');await page.keyboard.down('ArrowDown')
   try:await wait('window.__gravityCourierQA.detection_count>0 || window.__gravityCourierQA.state!==1',10000)
   finally:
    for key in ['Shift','ArrowRight','ArrowDown']:await page.keyboard.up(key)
   s=await q();assert s['state']==1 and s['detection_count']>0
   r['detection_state']={k:s[k] for k in ['detection_count','tension_mode','tension_intensity','heartbeat_count']}
   r['detected_output']=await page.evaluate('measureOutput(400)')
   assert r['detected_output']['rms_dbfs']>-40 and r['detected_output']['peak_dbfs']<-0.2,r['detected_output']
   r['checks'].append('Real guard detection starts distinct warning with measured non-silent, non-clipped output')
   # Check pause on a fresh attempt: do not race a nearby guard while sampling PCM.
   await page.keyboard.press('r');await wait('window.__gravityCourierQA.state===0')
   await page.keyboard.press('Space');await wait('window.__gravityCourierQA.state===1')
   await page.keyboard.press('Escape');await wait('window.__gravityCourierQA.state===2')
   await page.wait_for_timeout(700);r['paused_output']=await page.evaluate('measureOutput(500)')
   assert r['paused_output']['rms_dbfs']<r['calm_output']['rms_dbfs']-10
   r['checks'].append('Pause removes music/heartbeat from audible output while ambience remains quiet')
   assert not r['errors'];r['success']=True
  except Exception as e:
   r['success']=False;r['failure']=str(e)
   try:r['last_snapshot']=await q()
   except Exception:pass
  finally:await browser.close()
 (E/'v611-audio-game-report.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(r,ensure_ascii=True))
 if not r['success']:raise SystemExit(1)
if __name__=='__main__':
 import functools,threading
 from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
 class Quiet(SimpleHTTPRequestHandler):
  def log_message(self,*args):pass
 server=ThreadingHTTPServer(('127.0.0.1',8782),functools.partial(Quiet,directory=str(ROOT/os.environ.get('GAME_WEB_DIR','web'))))
 threading.Thread(target=server.serve_forever,daemon=True).start()
 try:asyncio.run(main())
 finally:server.shutdown();server.server_close()


