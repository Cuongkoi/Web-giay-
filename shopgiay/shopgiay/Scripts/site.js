document.querySelectorAll('img[data-fallback]').forEach(img=>img.addEventListener('error',()=>{img.src='/Images/placeholder.svg';},{once:true}));
document.querySelectorAll('form[data-confirm]').forEach(f=>f.addEventListener('submit',e=>{if(!confirm(f.dataset.confirm))e.preventDefault()}));
