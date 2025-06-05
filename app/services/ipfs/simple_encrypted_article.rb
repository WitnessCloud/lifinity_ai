require 'net/http'
require 'uri'
require 'json'
require 'tempfile'
require 'openssl'
require 'base64'

# 簡化版的加密文章類別
module Ipfs
  class SimpleEncryptedArticle
    ALGORITHM = 'AES-256-GCM'

    def initialize
      @cipher = OpenSSL::Cipher.new(ALGORITHM)
    end

    def encrypt_article(content, password = nil)
      key = password ? derive_key_from_password(password) : @cipher.random_key

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

    def decrypt_article(encrypted_data_hash)
      @cipher.decrypt
      @cipher.key = Base64.strict_decode64(encrypted_data_hash[:key])
      @cipher.iv = Base64.strict_decode64(encrypted_data_hash[:iv])
      @cipher.auth_tag = Base64.strict_decode64(encrypted_data_hash[:auth_tag])

      @cipher.update(Base64.strict_decode64(encrypted_data_hash[:encrypted_content])) + @cipher.final
    end

    private

    def derive_key_from_password(password, salt = 'stable_salt')
      OpenSSL::PKCS5.pbkdf2_hmac(password, salt, 10000, 32, OpenSSL::Digest::SHA256.new)
    end
  end
end
