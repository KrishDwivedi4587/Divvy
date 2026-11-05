const { computeSettlement } = require('../engine/settle.js');
const people = [{id:'aarav',name:'Aarav'},{id:'priya',name:'Priya'},{id:'zoya',name:'Zoya'}].map((p,i)=>({...p,colorIndex:i,initials:p.name.slice(0,2)}));
const it = (id,name,lt,q=1)=>({id,name,quantity:q,unitPrice:lt/q,lineTotal:lt,source:'manual'});
const base = {id:'b',title:'x',createdAt:'2026-11-14',people,
  items:[it('i1-paneer','Paneer Tikka',34000),it('i2-dal','Dal Makhani',28000),it('i3-coffee','Cold Coffee',15000),it('i4-naan','Butter Naan',16000,4)],
  assignments:{'i1-paneer':['aarav','priya'],'i2-dal':['aarav','priya','zoya'],'i3-coffee':['zoya'],'i4-naan':['aarav','priya','zoya']},
  adjustments:[{id:'service',label:'Service',kind:'service',mode:'percent',value:500,order:1,base:'itemsSubtotal',isNegative:false},
               {id:'tax',label:'GST',kind:'tax',mode:'percent',value:500,order:2,base:'runningTotal',isNegative:false}]};
const show=(b)=>{const s=computeSettlement(b);console.log(JSON.stringify({sub:s.itemsSubtotal,adj:s.adjustmentTotals,grand:s.grandTotal,rec:s.reconciles,pp:s.perPerson.map(p=>({id:p.personId,items:p.itemShares.map(x=>x.share),sub:p.subtotal,adj:p.adjustmentShares.map(a=>a.adjustmentId+':'+a.share),total:p.total}))},null,1));};
show(base);
show({...base,adjustments:[...base.adjustments,{id:'tip',label:'Tip',kind:'tip',mode:'amount',value:10000,order:3,base:'itemsSubtotal',isNegative:false}]});
