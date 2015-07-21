class TwilioController < ApplicationController
	
	skip_before_filter  :verify_authenticity_token
	
	def root
		require 'concurrent'
		
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
			r.Play "https://raw.githubusercontent.com/LingduoKong/pj_2/master/NoWorkingTimeRecord.mp3"
			r.Record :maxLength => '60', :transcribe => true, 
			:transcribeCallback=> '/send-record',
			:action => "/handle-record", :method => 'get'
		end
		render xml: response.text
	end
	
	def business
		
		# initialize all values
		if $numbers == nil
			$numbers = [{number:'+13122928193', isbusy: Concurrent::Atom.new(false)},
				{number:'+17752994774', isbusy: Concurrent::Atom.new(false)}]
		end
		if $incoming_calls == nil
			$incoming_calls = {}
		end
		if !$incoming_calls[params["Caller"]].present?
			$incoming_calls[params["Caller"]] = {}
			user = User.find_by_number(params["Caller"])
			if user.present?
				$incoming_calls[params["Caller"]]['name'] = user.name
			else
				$incoming_calls[params["Caller"]]['name'] = "unknown caller"
			end
		end
		
		index = 0
		$numbers.each do |number|
			if $incoming_calls[params['Caller']][number[:number]].present?
				if $incoming_calls[params['Caller']][number[:number]] == 'busy'
					if number[:isbusy].compare_and_set(false,true)
						break
					else
						index += 1
					end
				else
					index += 1
				end
			else
				if number[:isbusy].compare_and_set(false,true)
					$incoming_calls[params['Caller']][number[:number]] = 'not-busy'
				else
					$incoming_calls[params['Caller']][number[:number]] = 'busy'
				end
			end
		end
		
		puts index
		puts $numbers
		puts $incoming_calls

		time = TZInfo::Timezone.get('America/Chicago').now.to_i
		$incoming_calls[params['Caller']]['time'] = time
		
		if index >= $numbers.length 
			response = Twilio::TwiML::Response.new do |r|
				r.Play "https://raw.githubusercontent.com/LingduoKong/pj_2/master/WorkingTimeRecording.mp3"
				r.Record :maxLength => '30', :transcribe => true, 
				:transcribeCallback=> '/send-record',
				:action => "/handle-record?Caller=#{params["Caller"]}", :method => 'get'
			end
			
			Phone_call.create(
				inbound_number: params['Caller'],
				caller_name: $incoming_calls[params['Caller']]['name'],
				calling_time: $incoming_calls[params['Caller']]['time'],
				answer_number: nil, 
				duration: params['DialCallDuration'],
				status: 'answered by voice mail'
				)
			
			$incoming_calls.delete(params['Caller'])
	
		else
			
			response = Twilio::TwiML::Response.new do |r|
				r.Dial :timeout => '10', :action => "/dail-result?index=#{index}", :method => 'get' do |d|
					d.Number $numbers[index][:number]
				end
			end
			
			$incoming_calls[params["Caller"]]['time'] = time
			$incoming_calls[params["Caller"]]['calling_number'] = $numbers[index][:number]
			$incoming_calls[params["Caller"]]['status'] = 'ringing'

		end
		render xml: response.text
	end
	
	def dail_result
		puts params['DialCallStatus']
		index = params['index'].to_i
		
		if !$numbers[index][:isbusy].compare_and_set(true,false)
			puts 'thread error'
		end

		if params['DialCallStatus'] == 'no-answer' && params["CallStatus"] == 'completed'
			$incoming_calls[params['Caller']]['status'] = 'hang up by caller'
			Phone_call.create(
				inbound_number: params['Caller'],
				caller_name: $incoming_calls[params['Caller']]['name'],
				calling_time: $incoming_calls[params['Caller']]['time'],
				answer_number: $numbers[index][:number], 
				duration: 0,
				status: 'hang up by caller'
				)
			$incoming_calls.delete(params['Caller'])
			render nothing: true
		elsif params['DialCallStatus'] != 'completed'
			redirect_to "/business"
		else
			$incoming_calls[params['Caller']]['status'] = 'finish talking'
			$incoming_calls[params['Caller']]['Duration'] = params['DialCallDuration']
			Phone_call.create(
				inbound_number: params['Caller'],
				caller_name: $incoming_calls[params['Caller']]['name'],
				calling_time: $incoming_calls[params['Caller']]['time'],
				answer_number: $numbers[index][:number], 
				duration: params['DialCallDuration'],
				status: 'finish talking'
				)
			$incoming_calls.delete(params['Caller'])
			render nothing: true
		end
	end
end