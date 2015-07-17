class TwilioController < ApplicationController
	
	skip_before_filter  :verify_authenticity_token
	
	def root

		# @t = Twilio::TwiML::Response.new do |r|
		# 	r.Say "Hello #{name}"
		# 	r.Gather :numDigits => '1', :action => '/hello-monkey/handle-gather', :method => 'get' do |g|
		# 		g.Say 'To speak to a real monkey, press 1.'
		# 		g.Say 'Press 2 to record your own monkey howl.'
		# 		g.Say 'Press any other key to start over.'
		# 	end
		# end
		tz = TZInfo::Timezone.get('America/Chicago')
		h = tz.now.hour
		wday = tz.now.wday
		if h > 8 && h < 17 && wday != 0 && wday != 6
			redirect_to '/business'
		else
			# redirect_to '/non_business'
			redirect_to '/business'
		end
	end

	def numbers
		redirect '/' unless ['1', '2'].include?(params['Digits'])
		if params['Digits'] == '1'
			@response = Twilio::TwiML::Response.new do |r|
				r.Play 'http://demo.twilio.com/hellomonkey/monkey.mp3'
				# r.Say 'The call failed or the remote party hung up. Goodbye.'
			end
		elsif params['Digits'] == '2'
			@response = Twilio::TwiML::Response.new do |r|
				r.Say 'Record your monkey howl after the tone.'
				r.Record :maxLength => '30', :transcribe => true, 
				:transcribeCallback=> '/send-record',
				:action => '/handle-record', :method => 'get'
			end
		end
		render xml: @response.text
	end

	def record
		@t = Twilio::TwiML::Response.new do |r|
			r.Say 'Thanks for your patience. Goodbye.'
		end
		render xml: @t.text
	end

	def email
		if params['TranscriptionStatus']
			UserMailer.welcome_email(params['TranscriptionText']).deliver_now
		else 
			UserMailer.welcome_email("can not transcript that!").deliver_now
		end
		render nothing: true
	end

	def new_sms
		render 'new_sms'
	end
	
	def send_sms
		from = "+13122486093" # Your Twilio number
		account_sid = Rails.application.secrets.TWILIO_ACCOUNT_SID
		auth_token = Rails.application.secrets.TWILIO_AUTH_TOKEN
		client = Twilio::REST::Client.new account_sid, auth_token
		# friends.each do |key, value|
		# 	client.account.messages.create(
		# 		:from => from,
		# 		:to => params['to'],
		# 		:body => params['message']
		# 		)
		# end
		client.account.messages.create(
		:from => from,
		:to => params['to'],
		:body => params['message']
		)
		render nothing: true
	end
	
	def reply_sms
		twiml = Twilio::TwiML::Response.new do |r|
			r.Message "Hey Monkey. Thanks for the message!"
		end
		render xml: twiml.text
	end
	
	def calling_info
	end
	
	def calling_info_callback
		time = TZInfo::Timezone.get('America/Chicago').now
		if $incoming_calls == nil
			$incoming_calls = {}
		end
		$incoming_calls.each_pair do |key, value|
			if value["time"].to_i + 17 < time.to_i && value['status'] == 'ringing'
				$incoming_calls[key]['status'] = 'talking'
				$incoming_calls[key]['time'] = time.to_i
			end
		end
		render json: $incoming_calls
	end
	
	def calling_history_callback
		render json: @phone_calls = Phone_call.order(calling_time: :desc).limit(10)
	end
	
	def non_business
		response = Twilio::TwiML::Response.new do |r|
			r.Play "https://raw.githubusercontent.com/LingduoKong/project-2/master/NoWorkingTimeRecord.mp3"
			r.Say 'Leave your message after the tone.'
			r.Record :maxLength => '60', :transcribe => true, 
			:transcribeCallback=> '/send-record',
			:action => "/handle-record", :method => 'get'
		end
		render xml: response.text
	end
	
	def business
		
		$numbers = ['+13122928193']
		# $numbers = ['+17734928146','+14147597954']
		
		time = TZInfo::Timezone.get('America/Chicago').now.to_i
		
		if $incoming_calls == nil
			$incoming_calls = {}
		end
		
		if !$incoming_calls[params["Caller"]].present?
			$incoming_calls[params["Caller"]] = {}
		end
		
		if params['index'].present?
			index = params['index'].to_i
		else
			index = 0
		end
		
		response = Twilio::TwiML::Response.new do |r|
			if index < $numbers.length
				user = User.find_by_number(params["Caller"])
				if user.present?
					$incoming_calls[params["Caller"]]['name'] = user.name
				else
					$incoming_calls[params["Caller"]]['name'] = "unknown caller"
				end
				$incoming_calls[params["Caller"]]['time'] = time
				$incoming_calls[params["Caller"]]['calling_number'] = $numbers[index]
				$incoming_calls[params["Caller"]]['status'] = 'ringing'
				$incoming_calls[params['Caller']]['Duration'] = params['DialCallDuration']

				r.Dial :timeout => '10', :action => "/dail-result?index=#{index}", :method => 'get' do |d|
					d.Number $numbers[index]
				end
			else
				$incoming_calls[params["Caller"]]['calling_number'] = nil
				$incoming_calls[params["Caller"]]['status'] = 'answered by voice mail'
				r.Play "https://raw.githubusercontent.com/LingduoKong/project-2/master/WorkingTimeRecording.mp3"
				r.Record :maxLength => '30', :transcribe => true, 
				:transcribeCallback=> '/send-record',
				:action => "/handle-record?Caller=#{params["Caller"]}", :method => 'get'
				
				Phone_call.create(
				inbound_number: params['Caller'],
				caller_name: $incoming_calls[params['Caller']]['name'],
				calling_time: $incoming_calls[params['Caller']]['time'],
				answer_number: $numbers[index], 
				duration: params['DialCallDuration'],
				status: $incoming_calls[params["Caller"]]['status']
				)
				
			end
		end
		render xml: response.text
	end
	
	def dail_result
		puts params['DialCallStatus']
		index = params['index'].to_i
		
		if params['DialCallStatus'] == 'no-answer' && params["CallStatus"] == 'completed'
			$incoming_calls[params['Caller']]['status'] = 'hang up by caller'
			Phone_call.create(
				inbound_number: params['Caller'],
				caller_name: $incoming_calls[params['Caller']]['name'],
				calling_time: $incoming_calls[params['Caller']]['time'],
				answer_number: $numbers[index], 
				duration: 0,
				status: 'hang up by caller'
				)
			render nothing: true
		elsif params['DialCallStatus'] != 'completed'
			index += 1
			redirect_to "/business?index=#{index}"
		else
			$incoming_calls[params['Caller']]['status'] = 'finish talking'
			$incoming_calls[params['Caller']]['Duration'] = params['DialCallDuration']
			Phone_call.create(
				inbound_number: params['Caller'],
				caller_name: $incoming_calls[params['Caller']]['name'],
				calling_time: $incoming_calls[params['Caller']]['time'],
				answer_number: $numbers[index], 
				duration: params['DialCallDuration'],
				status: 'finish talking'
				)
			render nothing: true
		end
	end
end