(function(){
  var r=document.documentElement;
  var prefersDark=window.matchMedia('(prefers-color-scheme:dark)').matches;
  var theme=prefersDark?'dark':'light';
  r.setAttribute('data-theme',theme);
  document.addEventListener('DOMContentLoaded',function(){
    var btn=document.getElementById('theme-toggle');
    function setIcon(t){if(btn)btn.innerHTML=t==='dark'?'☀️':'🌙';}
    setIcon(theme);
    if(btn)btn.addEventListener('click',function(){
      var cur=r.getAttribute('data-theme');var next=cur==='dark'?'light':'dark';
      r.setAttribute('data-theme',next);setIcon(next);
    });
    var ham=document.getElementById('hamburger');var menu=document.getElementById('mobile-menu');
    if(ham&&menu)ham.addEventListener('click',function(){menu.classList.toggle('open');});
    document.querySelectorAll('[data-like]').forEach(function(btn){
      btn.addEventListener('click',async function(){
        var id=btn.dataset.like;
        try{var res=await fetch('/api/articles/'+id+'/like',{method:'POST',headers:{'Content-Type':'application/json'}});
          if(res.redirected||res.status===302){window.location='/auth/login';return;}
          var d=await res.json();
          btn.classList.toggle('liked',d.liked);
          var sp=btn.querySelector('.like-count');if(sp)sp.textContent=d.count;
        }catch(e){console.error(e);}
      });
    });
    var cf=document.getElementById('comment-form');
    if(cf){cf.addEventListener('submit',async function(e){
      e.preventDefault();var aid=cf.dataset.article;var ta=cf.querySelector('textarea');var content=ta.value.trim();if(!content)return;
      try{var res=await fetch('/api/articles/'+aid+'/komentarz',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({content})});
        if(res.redirected||res.status===302){window.location='/auth/login';return;}
        var d=await res.json();if(d.error){alert(d.error);return;}
        var list=document.getElementById('comments-list');var div=document.createElement('div');div.className='comment';
        div.innerHTML='<div class="comment__hd"><span class="avatar" style="width:32px;height:32px;font-size:.75rem">'+((d.user.display_name||'U')[0].toUpperCase())+'</span><span class="comment__author">'+d.user.display_name+'</span><span class="comment__date">teraz</span></div><p class="comment__body">'+content.replace(/</g,'&lt;')+'</p>';
        list.appendChild(div);ta.value='';
      }catch(e){console.error(e);}
    });}
  });
})();
