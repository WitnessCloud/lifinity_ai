require 'openssl'
require 'base64'
require 'json'
require 'digest'

class EncryptedArticle
  ALGORITHM = 'AES-256-GCM'

  def initialize
    @cipher = OpenSSL::Cipher.new(ALGORITHM)
  end

  # 生成安全的隨機密鑰
  def generate_key
    @cipher.random_key
  end

  # 加密文章
  def encrypt_article(content, key = nil)
    key ||= generate_key

    @cipher.encrypt
    @cipher.key = key

    # 生成隨機初始向量
    iv = @cipher.random_iv

    # 加密內容
    encrypted_data = @cipher.update(content) + @cipher.final

    # 獲取認證標籤（GCM 模式提供完整性驗證）
    auth_tag = @cipher.auth_tag

    # 將所有資料編碼成 Base64
    {
      encrypted_content: Base64.strict_encode64(encrypted_data),
      iv: Base64.strict_encode64(iv),
      auth_tag: Base64.strict_encode64(auth_tag),
      key: Base64.strict_encode64(key),
      algorithm: ALGORITHM
    }
  end

  # 解密文章
  def decrypt_article(encrypted_data)
    # 檢查輸入資料格式
    unless encrypted_data.is_a?(Hash)
      raise "encrypted_data 必須是 Hash 格式，包含 :encrypted_content, :iv, :auth_tag, :key"
    end

    required_keys = [:encrypted_content, :iv, :auth_tag, :key]
    missing_keys = required_keys - encrypted_data.keys
    unless missing_keys.empty?
      raise "encrypted_data 缺少必要的鍵值: #{missing_keys.join(', ')}"
    end

    @cipher.decrypt
    @cipher.key = Base64.strict_decode64(encrypted_data[:key])
    @cipher.iv = Base64.strict_decode64(encrypted_data[:iv])
    @cipher.auth_tag = Base64.strict_decode64(encrypted_data[:auth_tag])

    # 解密內容
    decrypted = @cipher.update(Base64.strict_decode64(encrypted_data[:encrypted_content])) + @cipher.final

    decrypted
  rescue OpenSSL::Cipher::CipherError => e
    raise "解密失敗: #{e.message}"
  rescue ArgumentError => e
    raise "Base64 解碼失敗: #{e.message}"
  end

  # 僅用 Base64 字串解密（簡化版本）
  def decrypt_simple(base64_string, key_string)
    raise "此方法需要完整的加密資料結構，請使用 decrypt_article 方法"
  end

  # 生成文章的雜湊值（用於驗證完整性）
  def generate_hash(content)
    Digest::SHA256.hexdigest(content)
  end
end

class Article
  attr_accessor :title, :content, :author, :created_at, :tags

  def initialize(title, content, author, tags = [])
    @title = title
    @content = content
    @author = author
    @created_at = Time.now
    @tags = tags
  end

  def to_json
    {
      title: @title,
      content: @content,
      author: @author,
      created_at: @created_at.to_s,
      tags: @tags
    }.to_json
  end

  def self.from_json(json_str)
    data = JSON.parse(json_str)
    article = new(data['title'], data['content'], data['author'], data['tags'])
    article.created_at = Time.parse(data['created_at']) if data['created_at']
    article
  end
end

class SecureArticleManager
  def initialize
    @encryptor = EncryptedArticle.new
    @articles = {}
  end

  # 建立並加密文章
  def create_encrypted_article(title, content, author, tags = [], password = nil)
    article = Article.new(title, content, author, tags)
    article_json = article.to_json

    # 如果提供密碼，使用密碼生成密鑰
    key = password ? derive_key_from_password(password) : @encryptor.generate_key

    encrypted_data = @encryptor.encrypt_article(article_json, key)
    article_id = generate_article_id(title, author)

    @articles[article_id] = {
      encrypted_data: encrypted_data,
      metadata: {
        title: title,
        author: author,
        created_at: Time.now,
        tags: tags,
        hash: @encryptor.generate_hash(article_json)
      }
    }

    article_id
  end

  # 解密並取得文章
  def get_article(article_id, password = nil)
    return nil unless @articles[article_id]

    encrypted_info = @articles[article_id]
    encrypted_data = encrypted_info[:encrypted_data]

    # 如果使用密碼加密，需要重新生成相同的密鑰
    if password
      key = derive_key_from_password(password)
      encrypted_data[:key] = Base64.strict_encode64(key)
    end

    decrypted_json = @encryptor.decrypt_article(encrypted_data)
    article = Article.from_json(decrypted_json)

    # 驗證完整性
    current_hash = @encryptor.generate_hash(decrypted_json)
    if current_hash != encrypted_info[:metadata][:hash]
      raise "文章完整性驗證失敗"
    end

    article
  end

  # 列出所有文章的元資料（不包含內容）
  def list_articles
    @articles.map do |id, info|
      {
        id: id,
        title: info[:metadata][:title],
        author: info[:metadata][:author],
        created_at: info[:metadata][:created_at],
        tags: info[:metadata][:tags]
      }
    end
  end

  # 匯出加密文章（用於 IPFS 存儲）
  def export_encrypted_article(article_id)
    @articles[article_id]
  end

  # 匯入加密文章（從 IPFS 載入）
  def import_encrypted_article(article_id, article_data)
    @articles[article_id] = article_data
  end

  private

  def derive_key_from_password(password, salt = 'stable_salt_for_demo')
    OpenSSL::PKCS5.pbkdf2_hmac(
      password,
      salt,
      10000,  # 迭代次數
      32,     # 密鑰長度（256 bits）
      OpenSSL::Digest::SHA256.new
    )
  end

  def generate_article_id(title, author)
    Digest::SHA256.hexdigest("#{title}_#{author}_#{Time.now.to_f}")[0..15]
  end
end
