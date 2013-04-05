require 'sinatra'
require 'json'
require 'git'
require 'heroku'
require 'coffee-script'
require 'less'
require 'dalli'

require './config/environments'
require './config/cache'
require './config/version'

get '/' do
  redirect "https://github.com/PeterHamilton/classy-cate#classy-cate"
end

# Asset Serving
get '/classy-cate.user.js' do
  get_cache('classy-cate-user-js', settings.asset_cache_for) {
    erb(:"classy_cate.user.js")
  }
end

get '/classy-cate.js' do
  get_cache('classy-cate-js', settings.asset_cache_for) {
    coffee(erb(:"classy_cate.coffee"))
  }
end

get '/classy-cate.css' do
  get_cache('classy-cate-css', settings.asset_cache_for) {
    less :classy_cate
  }
end

get '/timeline.js' do
  get_cache('timeline-js', settings.asset_cache_for) {
    coffee(:"timeline")
  }
end

get '/timeline.css' do
  get_cache('timeline-css', settings.asset_cache_for) {
    less :timeline
  }
end

# Auto Deploy Methods
get '/public_key' do
  require_relative 'lib/init'
  ::CURRENT_SSH_KEY
end

get '/status' do
  require_relative 'lib/init'
  c = GitPusher.local_state(ENV['GITHUB_REPO'])
  "SHA: #{c.sha} | Date: #{c.date}"
end

get '/nuke-repos' do
  require_relative 'lib/init'
  `rm -r repos`
  "nuked!"
end

get '/force-push' do
  require_relative 'lib/init'
  GitPusher.deploy(ENV['GITHUB_REPO'])
  "Success!"
end

post '/post-receive' do
  require_relative 'lib/init'
  data = JSON.parse(params[:payload])
  # if data["repository"]["private"]
  #   "freak out"
  # end
  url = data["repository"]["url"]
  GitPusher.deploy(url)
  begin
    logger.info "Flushing the Cache Post-Deploy"
    settings.cache.flush_all
  rescue Dalli::NetworkError
  end
  "Success!"
end
