export default class NavbarController {
  constructor() {
    this.hamburger = document.querySelector(".hamburger");
    this.nav = document.querySelector("nav");
    this.overlay = document.querySelector(".overlay");
    this.dropdowns = document.querySelectorAll(".dropdown");

    this.init();
  }

  init() {
    // 漢堡選單點擊事件
    this.hamburger?.addEventListener("click", this.toggleMenu.bind(this));

    // 點擊蒙版關閉選單
    this.overlay?.addEventListener("click", this.closeMenu.bind(this));

    // 手機版下拉選單點擊
    if (window.innerWidth <= 768) {
      this.initMobileDropdowns();
    }

    // 窗口大小變化時重置
    window.addEventListener("resize", this.handleResize.bind(this));
  }

  toggleMenu() {
    this.hamburger.classList.toggle("active");
    this.nav.classList.toggle("active");
    this.overlay.classList.toggle("active");
    document.body.style.overflow = this.nav.classList.contains("active")
      ? "hidden"
      : "";
  }

  closeMenu() {
    this.hamburger.classList.remove("active");
    this.nav.classList.remove("active");
    this.overlay.classList.remove("active");
    document.body.style.overflow = "";
  }

  initMobileDropdowns() {
    this.dropdowns.forEach((dropdown) => {
      dropdown.addEventListener("click", (e) => {
        if (window.innerWidth <= 768) {
          e.preventDefault();
          dropdown.classList.toggle("active");
        }
      });
    });
  }

  handleResize() {
    if (window.innerWidth > 768) {
      this.dropdowns.forEach((dropdown) => {
        dropdown.classList.remove("active");
      });
      this.closeMenu();
    }
  }
}
