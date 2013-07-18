require 'sinatra/auth/github'
require 'sinatra/assetpack'
require 'octokit'
require 'redcarpet'
require 'sass'
require 'yaml'
require "base64"
require "typhoeus"

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
      @name = @octokit.user[:name] || @octokit.user[:login]
      @login = @octokit.user[:login]
      @email = @octokit.user[:email] || ""
    end

    request.path_info.sub! %r{/$}, ''
  end

  not_found do
    markdown :notfound
  end

  # for all markdown files, keep using layout.erb
  set :markdown, :layout_engine => :erb

  get '/' do
    markdown :index
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
    erb :repos, :layout => false, :locals => { :octokit => @octokit }
  end

  post '/add-licenses' do
    license = File.read(File.join(DEPENDENCY_PATH, "licenses", "#{params['license']}.txt"))

    license.gsub!(/[year]/, Time.new.year.to_s)
    license.gsub!(/[login]/, @login)
    license.gsub!(/[email]/, @email)
    license.gsub!(/[fullname]/, @name)

    message = !params["message"].empty? ? params["message"] : "Add LICENSE file via addalicense.com"

    params["repositories"].each do |repo|
      repo_info = @octokit.repository(repo)
      license.gsub!(/[project]/, repo_info.name)
      license.gsub!(/[description]/, repo_info.description || "")
      
      @octokit.create_content(repo, "LICENSE.txt",  message, license)
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

    # doing it in parallel is way more performant
    # rescue block is needed in case a repo is completely empty
    def repositories_missing_licenses
      public_repos = []
      hydra = Typhoeus::Hydra.hydra
      @octokit.repositories.each_with_index do |repo, idx|
        request = Typhoeus::Request.new("https://api.github.com/repos/#{repo.full_name}/contents?access_token=#{ENV['GH_ADDALICENSE_ACCESS_TOKEN']}")
        request.on_complete do |response|
          if response.success?
            public_repos << repo unless JSON.load(response.response_body).any? {|f| f["name"] =~ /^LICENSE\.?/i}
          elsif response.timed_out?
            p "#{repo.full_name} got a time out"
          elsif response.code == 0
            # Could not get an http response, something's wrong.
            p "#{repo.full_name} " + response.curl_error_message
          elsif response.code == 404
            # don't worry about it; the repo is probably empty
          else
            # Received a non-successful http response.
            p "#{repo.full_name} HTTP request failed: " + response.code.to_s
          end
        end
        hydra.queue(request)
      end
      hydra.run
      return public_repos.sort_by { |r| r['full_name'] }
    end
  end
end