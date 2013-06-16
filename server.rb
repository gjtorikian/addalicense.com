require 'sinatra/auth/github'
require 'sinatra/assetpack'
require 'octokit'
require 'redcarpet'
require 'sass'

class AddALicense < Sinatra::Base
  set :root, File.dirname(__FILE__)
  enable :sessions

  configure :development, :testing do
    set :session_secret, "JUST_FOR_FIXING"
  end

  # "Thin is a supremely better performing web server so do please use it!"
  set :server, %w[thin webrick]

  register Sinatra::AssetPack
  assets {
    js :app, [
      '/js/*.js'
    ]

    css :application, [
      '/css/*.css'
    ]

    js_compression :closure, :level => "SIMPLE_OPTIMIZATIONS"
    css_compression :sass
  }

  set :github_options, {
    :scopes    => "user, public_repo",
    :secret    => ENV['GH_ADDALICENSE_SECRET_ID'],
    :client_id => ENV['GH_ADDALICENSE_CLIENT_ID'],
    :callback_url => "/callback"
  }

  register Sinatra::Auth::Github

  # trim trailing slashes
  before do
    request.path_info.sub! %r{/$}, ''
  end

  not_found do
    markdown :notfound
  end

  # for all markdown files, keep using layout.erb
  set :markdown, :layout_engine => :erb

  get '/' do
    if !authenticated?
      authenticate!
    else
      @octokit = Octokit::Client.new(:login => github_user.login, :oauth_token => github_user["token"], :auto_traversal => true)
      erb :index, :locals => { :login => github_user.login, :name => github_user.name, :public_repos => @octokit.repositories }
    end
  end

  get '/callback' do
    if authenticated?
      redirect "/"
    else
      authenticate!
    end
  end

  get '/about' do
    markdown :about
  end

  helpers do
    def title(number=nil)
      title = "Add a License"
    end
  end
end