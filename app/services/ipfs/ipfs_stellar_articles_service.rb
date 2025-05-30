module Ipfs
  class IpfsStellarArticlesService
    require 'net/http'
    require 'uri'
    require 'json'
    require 'fileutils'
    require 'digest'
    require 'time'

    IPFS_API_HOST = 'localhost'
    IPFS_API_PORT = 5001
    IPFS_GATEWAY = 'http://localhost:8080'

    def initialize(host: IPFS_API_HOST, port: IPFS_API_PORT, gateway: IPFS_GATEWAY)
      @host = host
      @port = port
      @gateway = gateway
      @base_url = "http://#{@host}:#{@port}/api/v0"

      check_connection!
    end

    def check_connection!
      begin
        response = http_post('/version')
        version_info = JSON.parse(response.body)

        Rails.logger.info(version_info['Version'])
      rescue => e
        Rails.logger.error(e.message)
        raise "IPFS link error"
      end
    end

    # 新增文章功能
    def create_article(title:, content:, author:, tags: [])
      # 构建文章数据
      article_data = {
        title: title,
        content: content,
        author: author,
        tags: tags,
        created_at: Time.now.utc.iso8601,
        version: "1.0",
        type: "stellar_article"
      }

      # 转换为 JSON
      json_content = JSON.pretty_generate(article_data)

      puts "📝 正在创建文章: #{title}"
      puts "作者: #{author}"
      puts "标签: #{tags.join(', ')}" unless tags.empty?

      # 添加到 IPFS
      hash = add_content_to_ipfs(json_content)

      puts "✅ 文章已成功发布到星际网络!"
      puts "📍 IPFS 哈希: #{hash}"
      puts "🌐 访问链接: #{@gateway}/ipfs/#{hash}"

      # 返回结果
      {
        hash: hash,
        title: title,
        author: author,
        gateway_url: "#{@gateway}/ipfs/#{hash}",
        created_at: article_data[:created_at]
      }
    end

    # 获取文章功能 - 新增这个方法！
    def get_article(hash)
      puts "📖 正在获取文章: #{hash}"

      begin
        content = cat_content(hash)
        article_data = JSON.parse(content)

        puts "✅ 文章获取成功"
        puts "标题: #{article_data['title']}"
        puts "作者: #{article_data['author']}"
        puts "创建时间: #{article_data['created_at']}"
        puts "标签: #{article_data['tags']&.join(', ')}"

        article_data
      rescue JSON::ParserError => e
        puts "❌ 解析文章数据失败: #{e.message}"
        nil
      rescue => e
        puts "❌ 获取文章失败: #{e.message}"
        nil
      end
    end

    # 取消固定内容
    def unpin_content(hash)
      begin
        params = { 'arg' => hash }
        response = http_post('/pin/rm', params)
        puts "📌 已从本地节点取消固定: #{hash}"
        true
      rescue => e
        puts "❌ 取消固定失败: #{e.message}"
        false
      end
    end

    # 在你的 service 中添加这个方法
    def list_pinned_content
      begin
        response = http_post('/pin/ls')
        data = JSON.parse(response.body)

        puts "📌 当前固定的内容:"
        if data['Keys'] && data['Keys'].any?
          data['Keys'].each do |hash, info|
            puts "  #{hash} (类型: #{info['Type'] if info})"
          end
        else
          puts "  没有固定的内容"
        end

        data
      rescue => e
        puts "❌ 获取固定列表失败: #{e.message}"
        nil
      end
    end

    private

    # 从 IPFS 获取内容
    # def cat_content(hash)
    #   params = { 'arg' => hash }
    #   response = http_get('/cat', params)
    #   response.body
    # end

    def cat_content(hash)
      params = { 'arg' => hash }
      response = http_post('/cat', params)
      response.body
    end

    # 添加内容到 IPFS
    def add_content_to_ipfs(content)
      # 构建 multipart form data
      boundary = "----WebKitFormBoundary#{rand(10**16)}"

      body_parts = []
      body_parts << "--#{boundary}"
      body_parts << 'Content-Disposition: form-data; name="file"; filename="article.json"'
      body_parts << "Content-Type: application/json"
      body_parts << ""
      body_parts << content
      body_parts << "--#{boundary}--"

      body = body_parts.join("\r\n")

      # 发送请求
      uri = URI("#{@base_url}/add")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      request.body = body

      response = http.request(request)

      unless response.code.to_i == 200
        raise "上传到 IPFS 失败: #{response.code} #{response.message}"
      end

      # 解析响应获取哈希
      result = JSON.parse(response.body.split("\n").last)
      result['Hash']
    end

    # HTTP POST 请求（IPFS API 主要使用 POST）
    def http_post(path, params = {})
      uri = URI("#{@base_url}#{path}")
      uri.query = URI.encode_www_form(params) unless params.empty?

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 30
      request = Net::HTTP::Post.new(uri)

      response = http.request(request)

      unless response.code.to_i == 200
        raise "HTTP 请求失败: #{response.code} #{response.message}"
      end

      response
    end

    def http_post(path, params = {})
      uri = URI("#{@base_url}#{path}")
      uri.query = URI.encode_www_form(params) unless params.empty?

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 30
      request = Net::HTTP::Post.new(uri)

      response = http.request(request)

      unless response.code.to_i == 200
        raise "HTTP 请求失败: #{response.code} #{response.message}"
      end

      response
    end

    # HTTP GET 请求（少数端点使用）
    # def http_get(path, params = {})
    #   uri = URI("#{@base_url}#{path}")
    #   uri.query = URI.encode_www_form(params) unless params.empty?

    #   http = Net::HTTP.new(uri.host, uri.port)
    #   http.read_timeout = 30
    #   request = Net::HTTP::Get.new(uri)

    #   response = http.request(request)

    #   unless response.code.to_i == 200
    #     raise "HTTP 请求失败: #{response.code} #{response.message}"
    #   end

    #   response
    # end
  end
end
