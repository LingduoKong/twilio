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
			$numbers = [
				# {number:'+17734928146', isbusy: Concurrent::Atom.new(false)},
				# {number:'+14147597954', isbusy: Concurrent::Atom.new(false)},
				# {number:'+14149302932', isbusy: Concurrent::Atom.new(false)}
				{number:'+12242009797', isbusy: Concurrent::Atom.new(false)},
				# {number:'+13122928193', isbusy: Concurrent::Atom.new(false)}
				]
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
					break
				else
					$incoming_calls[params['Caller']][number[:number]] = 'busy'
					index += 1
				end
			end
		end
		
		puts index
		puts $incoming_calls

		time = TZInfo::Timezone.get('America/Chicago').now.to_i
		$incoming_calls[params['Caller']]['time'] = time
		
		if index >= $numbers.length 
			response = Twilio::TwiML::Response.new do |r|
				r.Dial :timeout => '10', :action => "/dail-result", :method => 'get', :record => 'record-from-answer' do |d|
					# d.Number '+14149302932'
					d.Number '+13122928193'
				end
			end
			
			$incoming_calls[params["Caller"]]['calling_number'] = '+14149302932'
			$incoming_calls[params["Caller"]]['status'] = 'calling center answers'
		
		else
			
			response = Twilio::TwiML::Response.new do |r|
				r.Dial :timeout => '10', :action => "/dail-result?index=#{index}", :method => 'get', :record => 'record-from-answer' do |d|
					d.Number $numbers[index][:number]
				end
			end
			
			$incoming_calls[params["Caller"]]['calling_number'] = $numbers[index][:number]
			$incoming_calls[params["Caller"]]['status'] = 'ringing'

		end
		render xml: response.text
	end
	
	def dail_result
		puts params['DialCallStatus']
		
		if params['index'].present?
			index = params['index'].to_i
			if !$numbers[index][:isbusy].compare_and_set(true,false)
				puts 'thread error'
			end
		end
	
		if params['DialCallStatus'] == 'no-answer' && params["CallStatus"] == 'completed'
			$incoming_calls[params['Caller']]['status'] = 'hang up by caller'
			Phone_call.create(
				inbound_number: params['Caller'],
				caller_name: $incoming_calls[params['Caller']]['name'],
				calling_time: $incoming_calls[params['Caller']]['time'],
				answer_number: $incoming_calls[params['Caller']]['calling_number'], 
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
				answer_number: $incoming_calls[params['Caller']]['calling_number'], 
				duration: params['DialCallDuration'],
				status: 'finish talking',
				record_url: params['RecordingUrl']
				)
			$incoming_calls.delete(params['Caller'])
			render nothing: true
		end
			
	end
	
end