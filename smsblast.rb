require 'sinatra'
require 'sinatra/json'
require 'haml'

configure do
  enable :sessions
end

helpers do
  def username
    session[:auth]
  end
end

before '/secure/*' do
  unless session[:auth]
    session[:previous_url] = request.path
    @error = 'You must be logged in'
    halt haml :login_form
  end
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

post '/secure/send_message' do
  @targets = ['4046955106', '4046213436']
  @message = 'Hello from SMS Blast!'
  haml :send_message
end

get '/secure/sending_status' do
  json session[:sent_messages]
end
