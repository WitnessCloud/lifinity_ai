import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["filter", "storiesGrid", "storyCard", "emptyState"];

  connect() {
    // 检查是否有故事卡片，如果没有则显示空状态
    this.checkEmptyState();

    // 为卡片添加淡入动画
    if (this.hasStoryCardTarget) {
      this.storyCardTargets.forEach((card, index) => {
        setTimeout(() => {
          card.style.opacity = "1";
          card.style.transform = "translateY(0)";
        }, index * 100);
      });
    }
  }

  // 检查是否为空状态
  checkEmptyState() {
    if (this.hasEmptyStateTarget) {
      if (this.hasStoryCardTarget && this.storyCardTargets.length > 0) {
        // 有故事，隐藏空状态
        this.emptyStateTarget.style.display = "none";
        this.storiesGridTarget.style.display = "grid";
      } else {
        // 没有故事，显示空状态
        this.emptyStateTarget.style.display = "block";
        this.storiesGridTarget.style.display = "none";
      }
    }
  }

  // 过滤器功能
  filterAll(event) {
    this.setActiveFilter(event.currentTarget);
    this.showAllStories();
  }

  filterPublished(event) {
    this.setActiveFilter(event.currentTarget);
    this.filterStoriesByStatus("published");
  }

  filterDrafts(event) {
    this.setActiveFilter(event.currentTarget);
    this.filterStoriesByStatus("draft");
  }

  // 根据状态过滤故事
  filterStoriesByStatus(status) {
    let visibleCount = 0;

    this.storyCardTargets.forEach((card) => {
      if (card.dataset.status === status) {
        card.style.display = "block";
        visibleCount++;

        // 添加动画效果
        setTimeout(() => {
          card.style.opacity = "1";
          card.style.transform = "translateY(0)";
        }, 50);
      } else {
        card.style.opacity = "0";
        card.style.transform = "translateY(20px)";

        setTimeout(() => {
          card.style.display = "none";
        }, 300);
      }
    });

    // 检查过滤后是否有可见卡片
    if (visibleCount === 0) {
      this.emptyStateTarget.style.display = "block";
      this.emptyStateTarget.querySelector("p").textContent =
        `没有${status === "published" ? "已发布" : "草稿"}的故事`;
    } else {
      this.emptyStateTarget.style.display = "none";
    }
  }

  // 显示所有故事
  showAllStories() {
    this.storyCardTargets.forEach((card, index) => {
      card.style.display = "block";

      // 添加动画效果
      setTimeout(() => {
        card.style.opacity = "1";
        card.style.transform = "translateY(0)";
      }, index * 50);
    });

    // 如果有故事，隐藏空状态
    if (this.storyCardTargets.length > 0) {
      this.emptyStateTarget.style.display = "none";
    }
  }

  // 设置激活的过滤按钮
  setActiveFilter(button) {
    // 移除所有按钮的active类
    this.filterTarget.querySelectorAll(".filter-btn").forEach((btn) => {
      btn.classList.remove("active");
    });

    // 为当前按钮添加active类
    button.classList.add("active");
  }

  // 删除确认
  confirmDelete(event) {
    const confirmation = confirm("确定要删除这个故事吗？这个操作不能撤销。");
    if (!confirmation) {
      event.preventDefault();
    }
  }

  // 创建按钮动画
  animateButton(event) {
    const button = event.currentTarget;
    button.classList.add("animate-click");

    setTimeout(() => {
      button.classList.remove("animate-click");
    }, 300);
  }
}
