namespace :deploy do
  desc 'Deploy the app'
  task :production do
    app = "addalicense"
    remote = "git@heroku.com:#{app}.git"

    system "heroku maintenance:on --app #{app}"
    system "git push #{remote} master"
    system "heroku maintenance:off --app #{app}"
  end
end