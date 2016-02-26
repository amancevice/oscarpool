require 'bundler/setup'
Bundler.require

class Application < Sinatra::Base
  configure do
    enable :sessions
    set :assets_precompile, %w(application.js styles.css *.png *.jpg *.svg *.eot *.ttf *.woff)
    set :assets_css_compressor, :sass
    helpers  Sinatra::Cookies
    register Sinatra::AssetPipeline
    register Sinatra::Flash

    # Actual Rails Assets integration, everything else is Sprockets
    if defined?(RailsAssets)
      RailsAssets.load_paths.each do |path|
        settings.sprockets.append_path(path)
      end
    end
  end

  def self.title
    "Oscar Pool 2016"
  end

  before do
    unless request.path_info =~ /\A\/(login|signup|assets)\/?/
      @user = Pooler::User.first
      @user = Pooler::User.find_by email:session[:email]
      redirect '/login' if @user.nil?
    end
  end

  get '/' do
    erb :index
  end

  #
  # Authentication
  #

  get '/login' do
    erb :login
  end

  get '/signup' do
    erb :signup
  end

  get '/logout' do
    @user = session[:email] = nil
    redirect '/'
  end

  post '/login' do
    @user = Pooler::User.find_by email:params[:email]

    if @user.nil?
      flash[:error] = "Couldn\'t find #{params[:email]}. Try again or sign up."
      redirect '/login'
    elsif !@user.login(params[:password])
      flash[:error] = 'There was a problem signing in. Try again.'
      redirect '/login'
    end

    session[:email] = @user.email
    redirect session[:redirect]||'/'
  end

  post '/signup' do
    # Match passwords
    unless params[:password] == params[:confirm_password]
      flash[:error] = 'Passwords do not match. Try again.'
      redirect '/signup'
    end

    # Sign up
    @user = Pooler::User.signup params[:username], params[:email], params[:password]

    # Validate
    unless @user.errors.empty?
      flash[:error] = "That name/email was rejected for the following reasons:<br />&nbsp;&nbsp;&nbsp;#{@user.errors.full_messages.join "<br />&nbsp;&nbsp;&nbsp;"}"
      redirect '/signup'
    end

    # Log in
    session[:email] = @user.email

    redirect '/'
  end

  #
  # AJAX
  #

  post '/update/pick' do
    content_type :json
    unless @user.locked?
      option = Pooler::Option.find params['optionId'].to_i
      pick   = @user.picks.find_by category:option.category
      params[:categoryId]  = option&.category&.id
      params[:oldOptionId] = pick&.option&.id
      if pick&.option != option
        new_pick = @user.picks.create(
          category: option.category,
          option:   option,
          pick:     option.name,
          points:   option.points)
        params[:newOptionId] = option.id
      end
      pick&.delete
      params[:badgeCount] = 5 - @user.picks.select{|x| x.bonus }.count
      params[:submitable] = @user.picks.count == Pooler::Category.count

      params.to_json
    end
  end

  post '/update/gild' do
    content_type :json
    unless @user.locked?
      badge_count = 5 - @user.picks.select{|x| x.bonus }.count
      if badge_count > 0
        category    = Pooler::Option.find params['categoryId'].to_i
        pick        = @user.picks.find_by category:category
        pick&.update bonus:pick&.option&.points, penalty:-pick&.option&.points
        params[:optionId]   = pick&.option&.id
        params[:badgeCount] = badge_count - 1

        params.to_json
      end
    end
  end

  post '/submit' do
    content_type :json
    unless @user.locked? || @user.picks.count != Pooler::Category.count
      @user.lock!
      if @user.paid?
        { redirect:'#picks' }
      else
        { redirect:'#pay' }
      end.to_json
    end
  end

  #
  # ADMIN
  #

  post '/admin/winner' do
    content_type :json
    option = Pooler::Option.find params['optionId'].to_i
    category = option.category
    params[:categoryId]  = category.id
    params[:oldOptionId] = category.options.select{|x| x.correct? }.first&.id

    # Reset winners
    if option.correct?
      category.options.collect &:reset!
    # Set new winner
    else
      category.options.where.not(id:option.id).collect &:incorrect!
      option.correct!
      params[:newOptionId] = option.id
    end

    params.to_json
  end

  post '/admin/payment' do
    content_type :json
    user = Pooler::User.find params['userId'].to_i
    if user.paid?
      user.update! paid:nil
      params[:unpaidId] = user.id
    else
      user.pay!
      params[:paidId] = user.id
    end

    params.to_json
  end

  post '/admin/promote' do
    content_type :json
    user = Pooler::User.find params['userId'].to_i
    if user.admin == true
      user.update! admin:nil
      params[:unadminId] = user.id
    else
      user.update! admin:true
      params[:adminId] = user.id
    end

    params.to_json
  end

  post '/admin/unlock' do
    content_type :json
    user = Pooler::User.find params['userId'].to_i
    if user.locked?
      user.update! locked:nil
      params[:unlockId] = user.id
    end

    params.to_json
  end
end
