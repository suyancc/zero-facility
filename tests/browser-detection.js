async (page) => {
  await page.locator('canvas').focus();
  await page.keyboard.press('Enter');

  const targets=[[-3.9,0.65],[-1.3,-0.65]];
  let target=0,held=new Set(),samples=[],last;
  const until=Date.now()+9000;
  try {
    while(Date.now()<until) {
      last=await page.evaluate(()=>window.__gravityCourierQA);
      if(last.state===3 || last.state===4)break;
      if(last.state===2){await page.keyboard.press('Enter');continue;}
      const [x,z]=last.position, [vx,vz]=last.velocity;
      if(target<1 && Math.hypot(x-targets[target][0],z-targets[target][1])<0.57 && Math.hypot(vx,vz)<0.75)target++;
      let fx=(targets[target][0]-x)*2.5-vx*3.0, fz=(targets[target][1]-z)*2.5-vz*3.0;
      const ux=fx*0.874157-fz*0.485643, uy=fx*0.485643+fz*0.874157;
      const want=new Set();
      if(Math.abs(ux)>.55)want.add(ux>0?'ArrowRight':'ArrowLeft');
      if(Math.abs(uy)>.55)want.add(uy>0?'ArrowDown':'ArrowUp');
      for(const k of held)if(!want.has(k))await page.keyboard.up(k);
      for(const k of want)if(!held.has(k))await page.keyboard.down(k);
      held=want;
      if(samples.length<200)samples.push({t:last.time,p:last.position,fps:last.fps,target});
      await page.waitForTimeout(140);
    }
  } finally {for(const k of held)await page.keyboard.up(k);}
  await page.screenshot({path:'D:/code/python/go-dot-game/godot/exports/evidence/v2-web-detected.jpg',type:'jpeg',quality:80});
  return {won:last.state===3,target,last,sampleCount:samples.length,tail:samples.slice(-8),fps:samples.slice(10).map(x=>x.fps)};
}
