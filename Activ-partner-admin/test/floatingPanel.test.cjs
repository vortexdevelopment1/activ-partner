const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('typescript');
const path = require('node:path');
const output = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync(path.join(__dirname, '../src/utils/floatingPanel.ts'), 'utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText, {exports:output});
const { floatingPanel } = output;
for (const [width,height] of [[320,640],[360,740],[390,844],[430,932],[640,360],[768,1024],[1024,768],[1280,800],[1440,900]]) {
  test(`dropdown stays within a ${width} by ${height} viewport, including near edges`, () => {
    for (const top of [16,height/2,height-55]) for (const left of [8,width-260,width-80]) {
      const panel = floatingPanel({left,right:left+240,width:240,top,bottom:top+44},{left:0,top:0,width,height});
      const actualTop = panel.opensUp ? panel.top-panel.maxHeight : panel.top;
      const bottom = panel.opensUp ? panel.top : panel.top+panel.maxHeight;
      assert(panel.left >= 8 && panel.left+panel.width <= width-8);
      assert(actualTop >= 8 && bottom <= height-8);
    }
  });
}
test('opens above a field near the bottom of a short landscape modal', () => {
  assert.equal(floatingPanel({left:20,right:300,width:280,top:280,bottom:324},{left:0,top:0,width:320,height:360}).opensUp,true);
});
test('uses the visible area when an on-screen keyboard reduces and offsets the viewport', () => {
  const panel = floatingPanel({left:20,right:300,width:280,top:450,bottom:494},{left:0,top:100,width:320,height:300});
  assert(panel.top <= 392);
  assert(panel.top-panel.maxHeight >= 108);
});
