document.addEventListener("DOMContentLoaded", function () {
    const sideMenu = document.getElementById("sideMenu");

    document.addEventListener("mousemove", (e) => {
        if (e.clientX < 50) {
            sideMenu.style.transform = "translateX(0)";
        }
    });

    sideMenu.addEventListener("mouseleave", () => {
        sideMenu.style.transform = "translateX(-80%)";
    });

    document.querySelectorAll(".menu-option").forEach(option => {
        option.addEventListener("click", () => {
            const optionText = option.textContent.trim();
            console.log(`Selected option: ${optionText}`);
        });
    });

    document.querySelectorAll(".icon-card").forEach(card => {
        card.addEventListener("click", () => {
            const cardText = card.textContent.trim();
            console.log(`Selected card: ${cardText}`);
        });
    });
});