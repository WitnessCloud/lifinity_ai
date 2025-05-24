class HomeController < ApplicationController
  def index
  end

  # test 星際文章
  def show
    @hash = params[:hash]
    service = ::Ipfs::IpfsStellarArticlesService.new
    @article = service.get_article(@hash)
  end
end
