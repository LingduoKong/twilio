Rails.application.routes.draw do
  
# match ':controller(/:action(/:id))', :via => [:get,:post]
  
  get '/' => 'twilio#root'

  get '/handle-record' => 'twilio#record'

  post '/send-record' => 'twilio#email'
  
  get '/dail-result' => 'twilio#dail_result'
  
  get '/calling_info' => 'twilio#calling_info'
  
  get '/calling_info_callback' => 'twilio#calling_info_callback'
  
  get '/calling_history_callback' => 'twilio#calling_history_callback'
  
  get '/non_business' => 'twilio#non_business'
  
  get '/business' => 'twilio#business'
  
  get '/numbers' => 'twilio#numbers'
  
  post '/numbers' => 'twilio#update_numbers'
 
  get '/reports/statistics' => 'reports#statistics'

  get '/reports/history_stats' => 'reports#history_stats'
end
