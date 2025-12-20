let lastY = window.scrollY;
const header = document.getElementById("site-header");

if (header) {
  window.addEventListener(
    "scroll",
    () => {
      const y = window.scrollY;
      const delta = y - lastY;

      if (y > 120 && delta > 0) {
        header.style.transform = "translateY(-120%)";
        header.style.opacity = "0";
      } else {
        header.style.transform = "translateY(0)";
        header.style.opacity = "1";
      }

      lastY = y;
    },
    { passive: true }
  );
}
