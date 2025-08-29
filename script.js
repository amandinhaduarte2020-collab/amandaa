console.log("Meu primeiro site está funcionando!");

// Adicionar interatividade simples
document.addEventListener('DOMContentLoaded', function() {
    const header = document.querySelector('h1');
    header.addEventListener('click', function() {
        alert('Bem-vindo ao meu site!');
    });
});
