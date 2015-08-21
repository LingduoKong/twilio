Rails.application.routes.draw do
  
# match ':controller(/:action(/:id))', :via => [:get,:post]
  root 'reports#history_stats' 
 
  get '/' => 'reports#history_stats'

  get '/concierge_entrance' => 'twilio#concierge_entrance'

  get '/handle-record' => 'twilio#record'

  post '/send-record' => 'twilio#email'
  
  get '/dial-result' => 'twilio#dial_result'
  
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
