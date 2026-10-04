import asyncio,json,os,sys,threading,functools
from pathlib import Path
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from playwright.async_api import async_playwright
ROOT=Path(__file__).resolve().parents[1]
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
 report={'label':sys.argv[1],'operations':[],'errors':[]}
 async with async_playwright() as pw:
  browser=await pw.chromium.launch(executable_path=r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',headless=True,args=['--use-angle=d3d11'])
  page=await browser.new_page(viewport={'width':800,'height':600});await page.add_init_script(TAP)
  await page.add_init_script("window.__starts=0;const orig=AudioBufferSourceNode.prototype.start;AudioBufferSourceNode.prototype.start=function(...a){window.__starts++;return orig.apply(this,a)}")
  page.on('pageerror',lambda e:report['errors'].append(str(e)))
  await page.goto('http://127.0.0.1:8781/');await page.wait_for_function('window.__operationLab!==undefined',timeout=60000)
  await page.keyboard.press('Space');await page.wait_for_timeout(400)
  for kind in ['door','card','intel','download','control','override','pick','breach','core','deliver','exit']:
   await page.wait_for_function('(k)=>window.__operationLab.kind===k',arg=kind)
   starts=await page.evaluate('window.__starts');await page.keyboard.down('e')
   onset=await page.evaluate('measureOutput(140)');middle=await page.evaluate('measureOutput(800)')
   count=await page.evaluate('window.__starts')-starts
   await page.keyboard.up('e');await page.wait_for_timeout(120);stopped=await page.evaluate('measureOutput(150)')
   report['operations'].append({'kind':kind,'onset':onset,'middle':middle,'source_starts':count,'cancel':stopped})
   await page.keyboard.press('n')
  await page.keyboard.down('e');await page.wait_for_timeout(200);await page.keyboard.press('p');await page.wait_for_timeout(150);report['pause']=await page.evaluate('measureOutput(200)');await page.keyboard.up('e')
  if sys.argv[1]=='fixed':
   assert not report['errors']
   for row in report['operations']:
    assert row['source_starts']==1,row
    assert -42<row['onset']['rms_dbfs']<-15,row
    assert -40<row['middle']['rms_dbfs']<-15,row
    assert row['middle']['peak_dbfs']<-1,row
    assert row['cancel']['peak_dbfs']<-80,row
   assert report['pause']['peak_dbfs']<-80
   report['checks_passed']=len(report['operations'])*5+2
  await browser.close()
 path=ROOT/'exports/evidence'/('operation-pcm-'+sys.argv[1]+'.json');path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(report,indent=2));print(json.dumps(report))
class Quiet(SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=ThreadingHTTPServer(('127.0.0.1',8781),functools.partial(Quiet,directory=str(ROOT/'exports/operation-lab-web')))
threading.Thread(target=server.serve_forever,daemon=True).start()
try:asyncio.run(main())
finally:server.shutdown()

