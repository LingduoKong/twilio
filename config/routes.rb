Rails.application.routes.draw do
  
  match ':controller(/:action(/:id))', :via => [:get,:post]
  
  get '/' => 'twilio#root'

  get '/handle-gather' => 'twilio#numbers'

  get '/handle-record' => 'twilio#record'

  post '/send-record' => 'twilio#email'
  
  get '/new-message' => 'twilio#new_sms'
  
  post '/new-message' => 'twilio#send_sms'
  
  get '/dail-result' => 'twilio#dail_result'
  
  get '/reply-message' => 'twilio#reply_sms'
  
  get '/calling_info' => 'twilio#calling_info'
  
  get '/calling_info_callback' => 'twilio#calling_info_callback'
  
  get '/calling_history_callback' => 'twilio#calling_history_callback'
  
  get '/non_business' => 'twilio#non_business'
  
  get '/business' => 'twilio#business'
  
  get '/numbers' => 'twilio#numbers'
  
  post '/numbers' => 'twilio#update_numbers'
  
end
