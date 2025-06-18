# 主要的加密文章 + IPFS 系統
module Ipfs
  class EncryptedArticleIpfs
    def initialize
      @encryptor = SimpleEncryptedArticle.new
      @ipfs = SimpleIPFSClient.new
    end

    # 檢查系統狀態
    def check_status
      puts "=== 系統狀態檢查 ==="

      if @ipfs.connected?
        puts "✅ IPFS 連接正常"
        return true
      else
        puts "❌ IPFS 連接失敗"
        puts "請確認："
        puts "1. IPFS 已安裝"
        puts "2. IPFS daemon 正在運行"
        puts "3. API 在 localhost:5001 可用"
        return false
      end
    end

    # 創建加密文章並上傳到 IPFS
    def create_encrypted_article(title, content, password = nil)
      puts "\n=== 創建加密文章 ==="

      # 準備文章資料
      article_data = {
        title: title,
        content: content,
        created_at: Time.now.to_s,
        version: "1.0"
      }

      puts "準備加密文章: #{title}"

      # 加密文章內容
      encrypted_data = @encryptor.encrypt_article(article_data.to_json, password)

      puts "文章加密完成"

      # 包裝成完整的資料包
      article_package = {
        metadata: {
          title: title,
          encrypted: true,
          created_at: Time.now.to_s,
          has_password: !password.nil?
        },
        encrypted_data: encrypted_data
      }

      puts "正在上傳到 IPFS..."

      # 上傳到 IPFS
      result = @ipfs.add_json(article_package)
      ipfs_hash = result['Hash']

      puts "✅ 文章已上傳到 IPFS"
      puts "IPFS Hash: #{ipfs_hash}"

      {
        title: title,
        ipfs_hash: ipfs_hash,
        size: result['Size'],
        encrypted: true,
        has_password: !password.nil?
      }
    end

    # 從 IPFS 下載並解密文章
    def get_encrypted_article(ipfs_hash, password = nil)
      puts "\n=== 從 IPFS 獲取文章 ==="
      puts "IPFS Hash: #{ipfs_hash}"

      # 從 IPFS 下載
      puts "正在從 IPFS 下載..."
      article_package = @ipfs.get_json(ipfs_hash)

      puts "下載完成，正在解密..."

      # 解密文章
      encrypted_data = article_package[:encrypted_data]

      # 如果有密碼，需要重新生成密鑰
      if password
        temp_encrypted = @encryptor.encrypt_article("temp", password)
        encrypted_data[:key] = temp_encrypted[:key]
      end

      decrypted_json = @encryptor.decrypt_article(encrypted_data)
      article_data = JSON.parse(decrypted_json, symbolize_names: true)

      puts "✅ 文章解密成功"

      {
        title: article_data[:title],
        content: article_data[:content],
        created_at: article_data[:created_at],
        ipfs_hash: ipfs_hash,
        metadata: article_package[:metadata]
      }
    end

    # 分享文章（生成公開連結）
    def share_article(ipfs_hash)
      {
        ipfs_hash: ipfs_hash,
        ipfs_url: "ipfs://#{ipfs_hash}",
        gateway_url: "https://ipfs.io/ipfs/#{ipfs_hash}",
        dweb_url: "https://#{ipfs_hash}.ipfs.dweb.link/"
      }
    end
  end
end
