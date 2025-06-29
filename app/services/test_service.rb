class TestService

  def initialize
  end

  def call
  end

  private

  def format_params(options)
    {
      ipfs: options[:ipfs_hash],
      id: options[:id]
    }
  end

end
