// Themes + 3D tilt + loader (shared by index.html and admin.html)
(function(){
  var THEMES=[['neon','#ffb300'],['ocean','#2de2e6'],['sunset','#ff5e7a'],['forest','#b6f23b'],['rose','#ff7bd5'],['light','#e8ecff']];
  function setTheme(t){
    document.documentElement.setAttribute('data-theme',t);
    try{localStorage.setItem('mathra-theme',t);}catch(e){}
    var b=document.querySelectorAll('#themes button'); for(var i=0;i<b.length;i++) b[i].classList.toggle('on',b[i].dataset.t===t);
  }
  var saved='neon'; try{saved=localStorage.getItem('mathra-theme')||'neon';}catch(e){}
  document.documentElement.setAttribute('data-theme',saved);

  document.addEventListener('DOMContentLoaded',function(){
    var box=document.createElement('div'); box.id='themes'; box.title='Themes • තේමා';
    THEMES.forEach(function(t){ var b=document.createElement('button'); b.dataset.t=t[0]; b.style.background=t[1]; b.title=t[0]; b.onclick=function(){setTheme(t[0]);}; box.appendChild(b); });
    document.body.appendChild(box); setTheme(saved);
  });

  // 3D tilt on cards (mouse + touch)
  var cur=null;
  function tilt(e){
    var el=e.target.closest&&e.target.closest('.stat,.plan');
    if(cur&&cur!==el){cur.style.transform='';} cur=el; if(!el) return;
    var r=el.getBoundingClientRect(), x=(e.clientX-r.left)/r.width-.5, y=(e.clientY-r.top)/r.height-.5;
    el.style.transform='rotateY('+(x*16)+'deg) rotateX('+(-y*16)+'deg) translateY(-4px)';
  }
  document.addEventListener('pointermove',tilt);
  document.addEventListener('pointerleave',function(){ if(cur){cur.style.transform='';cur=null;} },true);
  document.addEventListener('pointerup',function(e){ if(e.pointerType==='touch'&&cur){cur.style.transform='';cur=null;} });

  // loader
  window.addEventListener('load',function(){
    setTimeout(function(){ var l=document.getElementById('loader'); if(l){ l.classList.add('done'); setTimeout(function(){l.remove();},700);} },1500);
  });
})();
