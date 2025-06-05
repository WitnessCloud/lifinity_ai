module Ipfs
  class EncryptedIpfsStellarArticlesService
    require 'net/http'
    require 'uri'
    require 'json'
    require 'fileutils'
    require 'digest'
    require 'time'
    require 'openssl'
    require 'base64'

    IPFS_API_HOST = 'localhost'
    IPFS_API_PORT = 5001
    IPFS_GATEWAY = 'http://localhost:8080'
    ALGORITHM = 'AES-256-GCM'

    def initialize(host: IPFS_API_HOST, port: IPFS_API_PORT, gateway: IPFS_GATEWAY)
      @host = host
      @port = port
      @gateway = gateway
      @base_url = "http://#{@host}:#{@port}/api/v0"
      @cipher = OpenSSL::Cipher.new(ALGORITHM)

      check_connection!
    end

    def check_connection!
      begin
        response = http_post('/version')
        version_info = JSON.parse(response.body)
        Rails.logger.info("IPFS Version: #{version_info['Version']}")
        puts "✅ IPFS 連接成功，版本: #{version_info['Version']}"
      rescue => e
        Rails.logger.error("IPFS 連接錯誤: #{e.message}")
        raise "IPFS 連接錯誤: #{e.message}"
      end
    end

    # 創建加密文章並上傳到 IPFS
    def create_encrypted_article(title:, content:, author:, tags: [], password: nil)
      puts "📝 正在創建加密文章: #{title}"
      puts "作者: #{author}"
      puts "標籤: #{tags.join(', ')}" unless tags.empty?
      puts "加密: #{password ? '是' : '否'}"

      # 建構文章資料
      article_data = {
        title: title,
        content: content,
        author: author,
        tags: tags,
        created_at: Time.now.utc.iso8601,
        version: "1.0",
        type: "encrypted_stellar_article"
      }

      # 轉換為 JSON
      json_content = JSON.pretty_generate(article_data)

      # 如果有密碼，進行加密
      if password
        puts "🔐 正在加密文章內容..."
        encrypted_data = encrypt_content(json_content, password)

        # 建立加密文章包
        encrypted_package = {
          metadata: {
            title: title,
            author: author,
            tags: tags,
            created_at: Time.now.utc.iso8601,
            encrypted: true,
            has_password: true,
            version: "1.0",
            type: "encrypted_stellar_article"
          },
          encrypted_data: encrypted_data
        }

        final_content = JSON.pretty_generate(encrypted_package)
        puts "✅ 文章加密完成"
      else
        # 未加密文章
        article_data[:encrypted] = false
        final_content = JSON.pretty_generate(article_data)
      end

      # 添加到 IPFS
      hash = add_content_to_ipfs(final_content)

      puts "✅ 文章已成功發布到星際網路!"
      puts "📍 IPFS 哈希: #{hash}"
      puts "🌐 訪問連結: #{@gateway}/ipfs/#{hash}"

      # 返回結果
      {
        hash: hash,
        title: title,
        author: author,
        encrypted: password ? true : false,
        has_password: password ? true : false,
        gateway_url: "#{@gateway}/ipfs/#{hash}",
        created_at: article_data[:created_at]
      }
    end

    # 獲取並解密文章
    def get_encrypted_article(hash, password: nil)
      puts "📖 正在獲取文章: #{hash}"

      begin
        content = cat_content(hash)
        article_data = JSON.parse(content)

        # 檢查是否為加密文章
        if article_data['encrypted_data']
          puts "🔓 檢測到加密文章，正在解密..."

          unless password
            puts "❌ 此文章需要密碼才能解密"
            return {
              error: "需要密碼",
              metadata: article_data['metadata'],
              encrypted: true
            }
          end

          # 解密文章
          encrypted_data = symbolize_keys(article_data['encrypted_data'])
          decrypted_content = decrypt_content(encrypted_data, password)
          original_article = JSON.parse(decrypted_content)

          puts "✅ 文章解密成功"
          puts "標題: #{original_article['title']}"
          puts "作者: #{original_article['author']}"
          puts "創建時間: #{original_article['created_at']}"
          puts "標籤: #{original_article['tags']&.join(', ')}"

          # 合併 metadata 和解密的內容
          result = original_article.merge({
            'hash' => hash,
            'encrypted' => true,
            'gateway_url' => "#{@gateway}/ipfs/#{hash}"
          })

          return result

        else
          # 未加密文章
          puts "✅ 獲取未加密文章成功"
          puts "標題: #{article_data['title']}"
          puts "作者: #{article_data['author']}"
          puts "創建時間: #{article_data['created_at']}"
          puts "標籤: #{article_data['tags']&.join(', ')}"

          article_data['hash'] = hash
          article_data['encrypted'] = false
          article_data['gateway_url'] = "#{@gateway}/ipfs/#{hash}"

          return article_data
        end

      rescue JSON::ParserError => e
        puts "❌ 解析文章資料失敗: #{e.message}"
        return { error: "資料格式錯誤", message: e.message }
      rescue OpenSSL::Cipher::CipherError => e
        puts "❌ 解密失敗，可能是密碼錯誤: #{e.message}"
        return { error: "解密失敗", message: "密碼可能不正確" }
      rescue => e
        puts "❌ 獲取文章失敗: #{e.message}"
        return { error: "獲取失敗", message: e.message }
      end
    end

    # 分享文章資訊
    def share_article(hash)
      {
        hash: hash,
        ipfs_url: "ipfs://#{hash}",
        gateway_url: "#{@gateway}/ipfs/#{hash}",
        dweb_url: "https://#{hash}.ipfs.dweb.link/",
        public_gateway: "https://ipfs.io/ipfs/#{hash}"
      }
    end

    # 批量創建文章（測試用）
    def batch_create_test_articles
      puts "🧪 創建測試文章..."

      articles = []

      # 未加密文章
      result1 = create_encrypted_article(
        title: "IPFS 入門指南",
        content: "IPFS (InterPlanetary File System) 是一個分散式的檔案系統，旨在創建一個持久且分散的儲存和分享檔案的方法。",
        author: "技術專家",
        tags: ["IPFS", "技術", "入門"]
      )
      articles << result1

      # 加密文章
      result2 = create_encrypted_article(
        title: "我的私密日記",
        content: "今天學會了如何在 IPFS 上創建加密文章，這真是太酷了！現在我的文章可以安全地存儲在分散式網路上。",
        author: "日記作者",
        tags: ["日記", "私密", "學習"],
        password: "my_secret_123"
      )
      articles << result2

      # 另一個加密文章
      result3 = create_encrypted_article(
        title: "區塊鏈技術深度分析",
        content: "這是一份關於區塊鏈技術的深度分析報告，包含了最新的技術趨勢和市場分析。內容僅供內部參考。",
        author: "研究員",
        tags: ["區塊鏈", "分析", "機密"],
        password: "blockchain_2024"
      )
      articles << result3

      puts "\n✅ 測試文章創建完成！"
      puts "="*50
      articles.each_with_index do |article, index|
        puts "文章 #{index + 1}:"
        puts "  標題: #{article[:title]}"
        puts "  哈希: #{article[:hash]}"
        puts "  加密: #{article[:encrypted] ? '是' : '否'}"
        puts "  連結: #{article[:gateway_url]}"
        puts ""
      end

      articles
    end

    # 取消固定內容
    def unpin_content(hash)
      begin
        params = { 'arg' => hash }
        response = http_post('/pin/rm', params)
        puts "📌 已從本地節點取消固定: #{hash}"
        true
      rescue => e
        puts "❌ 取消固定失敗: #{e.message}"
        false
      end
    end

    # 列出固定的內容
    def list_pinned_content
      begin
        response = http_post('/pin/ls')
        data = JSON.parse(response.body)

        puts "📌 當前固定的內容:"
        if data['Keys'] && data['Keys'].any?
          data['Keys'].each do |hash, info|
            puts "  #{hash} (類型: #{info['Type'] if info})"
          end
        else
          puts "  沒有固定的內容"
        end

        data
      rescue => e
        puts "❌ 獲取固定列表失敗: #{e.message}"
        nil
      end
    end

    private

    # 加密內容
    def encrypt_content(content, password)
      key = derive_key_from_password(password)

      @cipher.encrypt
      @cipher.key = key
      iv = @cipher.random_iv

      encrypted_data = @cipher.update(content) + @cipher.final
      auth_tag = @cipher.auth_tag

      {
        encrypted_content: Base64.strict_encode64(encrypted_data),
        iv: Base64.strict_encode64(iv),
        auth_tag: Base64.strict_encode64(auth_tag),
        key: Base64.strict_encode64(key),
        algorithm: ALGORITHM
      }
    end

    # 解密內容
    def decrypt_content(encrypted_data_hash, password)
      # 重新生成密鑰
      key = derive_key_from_password(password)

      @cipher.decrypt
      @cipher.key = key
      @cipher.iv = Base64.strict_decode64(encrypted_data_hash[:iv])
      @cipher.auth_tag = Base64.strict_decode64(encrypted_data_hash[:auth_tag])

      @cipher.update(Base64.strict_decode64(encrypted_data_hash[:encrypted_content])) + @cipher.final
    end

    # 從密碼派生密鑰
    def derive_key_from_password(password, salt = 'stellar_articles_salt_2024')
      OpenSSL::PKCS5.pbkdf2_hmac(
        password,
        salt,
        10000,  # 迭代次數
        32,     # 密鑰長度（256 bits）
        OpenSSL::Digest::SHA256.new
      )
    end

    # 將字串鍵轉換為符號鍵
    def symbolize_keys(hash)
      hash.transform_keys(&:to_sym)
    end

    # 從 IPFS 獲取內容
    def cat_content(hash)
      params = { 'arg' => hash }
      response = http_post('/cat', params)
      response.body
    end

    # 添加內容到 IPFS
    def add_content_to_ipfs(content)
      # 建構 multipart form data
      boundary = "----WebKitFormBoundary#{rand(10**16)}"

      body_parts = []
      body_parts << "--#{boundary}"
      body_parts << 'Content-Disposition: form-data; name="file"; filename="article.json"'
      body_parts << "Content-Type: application/json"
      body_parts << ""
      body_parts << content
      body_parts << "--#{boundary}--"

      body = body_parts.join("\r\n")

      # 發送請求
      uri = URI("#{@base_url}/add")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      request.body = body

      response = http.request(request)

      unless response.code.to_i == 200
        raise "上傳到 IPFS 失敗: #{response.code} #{response.message}"
      end

      # 解析回應獲取哈希
      result = JSON.parse(response.body.split("\n").last)
      result['Hash']
    end

    # HTTP POST 請求（IPFS API 主要使用 POST）
    def http_post(path, params = {})
      uri = URI("#{@base_url}#{path}")
      uri.query = URI.encode_www_form(params) unless params.empty?

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 30
      request = Net::HTTP::Post.new(uri)

      response = http.request(request)

      unless response.code.to_i == 200
        raise "HTTP 請求失敗: #{response.code} #{response.message}"
      end

      response
    end
  end
end
