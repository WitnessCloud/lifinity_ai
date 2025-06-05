# 簡化版的 IPFS 客戶端
class SimpleIpfsClient
  def initialize(host = 'localhost', port = 5001)
    @host = host
    @port = port
    @base_url = "http://#{@host}:#{@port}/api/v0"
  end

  # 檢查 IPFS 連接
  def connected?
    uri = URI("#{@base_url}/id")
    Net::HTTP.start(uri.host, uri.port, read_timeout: 5, open_timeout: 5) do |http|
      request = Net::HTTP::Post.new(uri)
      response = http.request(request)
      response.code == '200'
    end
  rescue
    false
  end

  # 上傳 JSON 資料到 IPFS
  def add_json(data)
    Tempfile.create(['ipfs_data', '.json']) do |temp_file|
      temp_file.write(data.to_json)
      temp_file.close
      add_file(temp_file.path)
    end
  end

  # 上傳檔案到 IPFS
  def add_file(file_path)
    uri = URI("#{@base_url}/add")

    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Post.new(uri)

      boundary = "----WebKitFormBoundary#{Time.now.to_i}"
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"

      file_content = File.read(file_path)
      filename = File.basename(file_path)

      body = []
      body << "--#{boundary}"
      body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\""
      body << "Content-Type: application/octet-stream"
      body << ""
      body << file_content
      body << "--#{boundary}--"

      request.body = body.join("\r\n")

      response = http.request(request)

      if response.code == '200'
        JSON.parse(response.body)
      else
        raise "IPFS 上傳失敗: #{response.code} - #{response.body}"
      end
    end
  end

  # 從 IPFS 下載檔案
  def get_file(hash)
    uri = URI("#{@base_url}/cat?arg=#{hash}")

    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Post.new(uri)
      response = http.request(request)

      if response.code == '200'
        response.body
      else
        raise "IPFS 下載失敗: #{response.code} - #{response.body}"
      end
    end
  end

  # 從 IPFS 取得 JSON 資料
  def get_json(hash)
    json_str = get_file(hash)
    JSON.parse(json_str, symbolize_names: true)
  end
end
