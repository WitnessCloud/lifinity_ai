# 加密 IPFS 文章系統使用指南

## 快速開始

### 1. 初始化服務
```ruby
# 在你的 Rails 應用中
service = Ipfs::EncryptedIpfsStellarArticlesService.new

# 或指定自定義設定
service = Ipfs::EncryptedIpfsStellarArticlesService.new(
  host: 'localhost',
  port: 5001,
  gateway: 'http://localhost:8080'
)
```

### 2. 創建文章

#### 未加密文章
```ruby
result = service.create_encrypted_article(
  title: "IPFS 技術介紹",
  content: "IPFS 是一個分散式檔案系統...",
  author: "技術專家",
  tags: ["IPFS", "技術"]
)

puts "文章哈希: #{result[:hash]}"
puts "訪問連結: #{result[:gateway_url]}"
```

#### 加密文章
```ruby
result = service.create_encrypted_article(
  title: "機密報告",
  content: "這是一份重要的機密報告...",
  author: "研究員",
  tags: ["機密", "報告"],
  password: "my_secret_password"
)

puts "加密文章哈希: #{result[:hash]}"
puts "加密狀態: #{result[:encrypted]}"
```

### 3. 獲取文章

#### 獲取未加密文章
```ruby
article = service.get_encrypted_article("QmHash...")

if article[:error]
  puts "錯誤: #{article[:error]}"
else
  puts "標題: #{article['title']}"
  puts "內容: #{article['content']}"
  puts "作者: #{article['author']}"
end
```

#### 獲取加密文章
```ruby
article = service.get_encrypted_article(
  "QmHash...",
  password: "my_secret_password"
)

if article[:error]
  puts "解密失敗: #{article[:error]}"
else
  puts "解密成功!"
  puts "標題: #{article['title']}"
  puts "內容: #{article['content']}"
end
```

### 4. 分享文章
```ruby
share_info = service.share_article("QmHash...")

puts "IPFS URI: #{share_info[:ipfs_url]}"
puts "Gateway: #{share_info[:gateway_url]}"
puts "DWeb 連結: #{share_info[:dweb_url]}"
puts "公共 Gateway: #{share_info[:public_gateway]}"
```

## 實用範例

### Controller 中的使用
```ruby
class ArticlesController < ApplicationController
  def create
    service = Ipfs::EncryptedIpfsStellarArticlesService.new

    result = service.create_encrypted_article(
      title: params[:title],
      content: params[:content],
      author: current_user.name,
      tags: params[:tags] || [],
      password: params[:password] # 可選
    )

    if result[:hash]
      render json: {
        success: true,
        hash: result[:hash],
        gateway_url: result[:gateway_url],
        encrypted: result[:encrypted]
      }
    else
      render json: { success: false, error: "上傳失敗" }
    end
  end

  def show
    service = Ipfs::EncryptedIpfsStellarArticlesService.new
    hash = params[:hash]
    password = params[:password]

    article = service.get_encrypted_article(hash, password: password)

    if article[:error]
      render json: {
        success: false,
        error: article[:error],
        encrypted: article[:encrypted]
      }
    else
      render json: {
        success: true,
        article: article
      }
    end
  end
end
```

### 前端表單範例
```erb
<!-- 創建文章表單 -->
<%= form_with url: articles_path, local: false, data: { remote: true } do |f| %>
  <%= f.text_field :title, placeholder: "文章標題" %>
  <%= f.text_area :content, placeholder: "文章內容" %>
  <%= f.text_field :tags, placeholder: "標籤 (用逗號分隔)" %>

  <!-- 可選的密碼欄位 -->
  <div>
    <%= f.check_box :use_password %>
    <%= f.label :use_password, "加密此文章" %>
  </div>

  <div id="password_field" style="display: none;">
    <%= f.password_field :password, placeholder: "請輸入密碼" %>
  </div>

  <%= f.submit "發布到 IPFS" %>
<% end %>

<script>
document.getElementById('use_password').addEventListener('change', function() {
  document.getElementById('password_field').style.display =
    this.checked ? 'block' : 'none';
});
</script>
```

## 批量測試

### 創建測試文章
```ruby
# 創建多個測試文章
service = Ipfs::EncryptedIpfsStellarArticlesService.new
articles = service.batch_create_test_articles

# 輸出結果
articles.each do |article|
  puts "#{article[:title]}: #{article[:hash]}"
end
```

### 驗證所有文章
```ruby
test_passwords = [nil, "my_secret_123", "blockchain_2024"]

articles.each_with_index do |article, index|
  password = test_passwords[index]

  result = service.get_encrypted_article(article[:hash], password: password)

  if result[:error]
    puts "❌ #{article[:title]}: #{result[:error]}"
  else
    puts "✅ #{article[:title]}: 成功"
  end
end
```

## 錯誤處理

### 常見錯誤和解決方案

1. **IPFS 連接失敗**
```ruby
begin
  service = Ipfs::EncryptedIpfsStellarArticlesService.new
rescue => e
  puts "IPFS 連接失敗: #{e.message}"
  # 確認 IPFS daemon 正在運行
end
```

2. **解密失敗**
```ruby
article = service.get_encrypted_article(hash, password: password)

case article[:error]
when "需要密碼"
  puts "此文章需要密碼才能查看"
when "解密失敗"
  puts "密碼不正確"
else
  puts "文章內容: #{article['content']}"
end
```

3. **上傳失敗**
```ruby
begin
  result = service.create_encrypted_article(...)
rescue => e
  puts "上傳失敗: #{e.message}"
  # 檢查 IPFS 節點狀態和網路連接
end
```

## 安全提醒

1. **密碼管理**: 密碼遺失將無法恢復文章內容
2. **網路安全**: 加密文章在 IPFS 網路上是公開的，但內容已加密
3. **密鑰安全**: 避免在程式碼中硬編碼密碼
4. **定期備份**: 保存重要的 IPFS 哈希值

## 進階功能

### 自定義加密設定
```ruby
# 如需要修改加密演算法或其他設定
# 可以在 service 類別中調整 ALGORITHM 常數
```

### 批量管理
```ruby
# 列出固定的內容
service.list_pinned_content

# 取消固定不需要的內容
service.unpin_content("QmHash...")
```

這個系統現在完全整合了你原有的 IPFS service 和新的加密功能！
