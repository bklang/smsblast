require 'sinatra'
require 'sinatra/json'
require 'haml'
require 'redis'
require 'phony'
require 'json'
require 'faraday'
require 'securerandom'

MAX_HISTORY = 50

configure do
  enable :sessions
end

helpers do
  def send_messages(targets, message)
    targets = targets.inject({}) do |targets, target|
      target = "1#{target}" unless target[0] == "1"
      if Phony.plausible?(target, cc: '1')
        target = Phony.normalize(target, cc: '1')
        id = record_attempt target, message
        targets[id] = target
      end
      targets
    end

    send_to_tropo targets, message
  end

  def send_to_tropo(targets, message)
    params = {
      token: ENV['TROPO_TOKEN'],
      targets: targets.to_json, # Hack to get around Tropo's nested params limitation
      message: message
    }

    Faraday.post("http://api.tropo.com/1.0/sessions") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['Accept'] = 'application/json'
      req.body = params.to_json
    end
  end

  def record_attempt(target, message, status = "Queued")
    id = "id-#{SecureRandom.hex 8}" # Use a short ID in case we overflow a GET size limit -- see Tropo hack above
    @redis.lpush 'calls', id
    @redis.hmset id, 'message', message, 'time', Time.now.to_i, 'status', status, 'target', target
    id
  end

  def update_attempt(id, status)
    @redis.hmset id, 'status', status, 'time', Time.now.to_i
  end

  def get_statuses
    statuses = @redis.lrange('calls', 0, MAX_HISTORY).inject({}) do |statuses, id|
      statuses[id] = @redis.hgetall id
      statuses
    end
  end

  def id_for_target(target)
    @redis.keys('id*').detect do |key|
      @redis.hget(key, 'target') == target
    end
  end

  def cleanup_old_attempts
    num_to_clean = @redis.llen('calls') - MAX_HISTORY
    if num_to_clean > 0
      num_to_clean.times do
        num = @redis.rpop 'calls'
        @redis.del num
      end
    end
  end

  def get_redis
    @redis = Redis.new url: ENV['REDISTOGO_URL']
  end
end

before '/secure/*' do
  unless session[:auth] == ENV['PASSWORD']
    session[:previous_url] = request.path
    @error = 'You must be logged in'
    halt haml :login_form
  end

  get_redis
end

get '/' do
  haml :login_form
end


get '/login/form' do
  haml :login_form
end

post '/login/attempt' do
  session[:auth] = params['password']
  redirect to '/secure/create_message'
end

get '/logout' do
  session.delete(:auth)
  haml "%div{class: 'alert alert-message'} Logged out"
end

get '/secure/create_message' do
  haml :create_message
end

get '/secure/message_status' do
  @statuses = get_statuses
  haml :message_status
end

post '/secure/send_message' do
  @targets = params['targets'].split "\n"
  @message = params['message']

  send_messages @targets, @message
  cleanup_old_attempts

  redirect to '/secure/message_status'
end

post '/tropo/update' do
  puts "Handling Tropo update with params: #{params.inspect}"
  if params['token'] == ENV['TROPO_TOKEN']
    puts "Valid Tropo Token."
  else
    puts "INVALID TROPO TOKEN! Ignoring update."
  end

  # We are not in the "secure" area so we need to instantiate Redis
  get_redis
  puts "Update params from Tropo: #{params.inspect}"
  update_attempt params['id'], params['status']
end

