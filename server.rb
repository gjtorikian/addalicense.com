require 'sinatra/auth/github'
require 'sinatra/assetpack'
require 'octokit'
require 'redcarpet'
require 'sass'
require 'yaml'
require "base64"

class AddALicense < Sinatra::Base
  set :root, File.dirname(__FILE__)
  enable :sessions

  DEPENDENCY_PATH = File.join(File.dirname(__FILE__), "deps")
  LICENSES_HASH = YAML.load(File.read(File.join(DEPENDENCY_PATH, "licenses.yml")))

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
    if authenticated?
      @octokit = Octokit::Client.new(:login => github_user.login, :oauth_token => github_user["token"], :auto_traversal => true)
    end

    request.path_info.sub! %r{/$}, ''
  end

  not_found do
    markdown :notfound
  end

  # for all markdown files, keep using layout.erb
  set :markdown, :layout_engine => :erb

  get '/' do
    erb :index
  end

  get '/add' do
    if !authenticated?
      authenticate!
    else
      erb :add, :locals => { :login => github_user.login, :licenses => LICENSES_HASH }
    end
  end

  get '/callback' do
    if authenticated?
      redirect "/add"
    else
      authenticate!
    end
  end

  get '/repos' do
    erb :repos, :layout => false, :locals => { :login => github_user.login, :octokit => @octokit }
  end

  post '/add-licenses' do
    year = Time.new.year.to_s
    license = File.read(File.join(DEPENDENCY_PATH, "licenses", "#{params['license']}.txt"))
    license = license.gsub(/<<year>>/, year).gsub(/<<fullname>>/, github_user.name)

    params["repositories"].each do |repository|
      @octokit.create_content(repository, "LICENSE", "Add LICENSE file via addalicense.com", license )
    end

    redirect '/finished'
  end

  get '/finished' do
    markdown :finished
  end

  get '/about' do
    markdown :about
  end

  get '/logout' do
    logout!
    redirect '/'
  end

  helpers do
    def title(number=nil)
      title = "Add a License"
    end

    def has_license?(repo)
      begin
        root_contents = @octokit.contents(repo.full_name)
        root_contents.any? {|f| f[:name] =~ /LICENSE\.?/}
      rescue Octokit::NotFound
        false
      end
    end
  end
end