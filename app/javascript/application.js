// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";
import NavbarController from "./controllers/navbar_controller";

document.addEventListener("DOMContentLoaded", function () {
  // 初始化導航欄控制器
  if (document.querySelector(".hamburger") && document.querySelector("nav")) {
    new NavbarController();
  }

  // 在這裡可以初始化其他控制器或功能
});

// 其他應用程式邏輯...

console.log("Hello, world!");
