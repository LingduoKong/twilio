class TwilioController < ApplicationController
	
	skip_before_filter  :verify_authenticity_token
	
	def concierge_entrance
		tz = TZInfo::Timezone.get('America/Chicago')
		h = tz.now.hour
		wday = tz.now.wday
		
		if $incoming_calls == nil
			$incoming_calls = {}
		end
		
		if h > 8 && h < 17 && wday != 0 && wday != 6
			uuid = UUID.new.generate
			$incoming_calls[uuid] = { :Caller => params["Caller"] }
			redirect_to "/business?uuid=#{uuid}"
		else
			pc = Phone_call.new
			pc.inbound_number = params['Caller']
			user = User.find_by_number(params["Caller"])
			if user.present?
				pc.caller_name = user.last_name + " " + user.first_name[0] + "."
			else
				pc.caller_name = "unknown caller"
			end
			pc.calling_time = tz.now.to_i
			pc.answer_number = "+18008008888"
			pc.status = "answered by voice mail"
			pc.duration = 0
			pc.save
			$phone_history = Phone_call.order(calling_time: :desc).limit(10)
			id = pc.id
			redirect_to "/non_business?id=#{id}"
		end
	end

	def record
		pc = Phone_call.find_by_id(params["id"].to_i)
		pc.record_url = params['RecordingUrl']
		pc.save
		$phone_history = Phone_call.order(calling_time: :desc).limit(10)	
		@t = Twilio::TwiML::Response.new do |r|
			r.Say 'Thanks for your patience. Goodbye.'
		end
		render xml: @t.text
	end

	def email
		pc = Phone_call.find_by_id(params["id"].to_i)
		pc.record_url = params['RecordingUrl']
		pc.save	
		if params['TranscriptionStatus']
			UserMailer.welcome_email(params['TranscriptionText']).deliver_now
		else 
			UserMailer.welcome_email("can not transcript that!").deliver_now
		end
		render nothing: true
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
		if $phone_history == nil
			$phone_history = Phone_call.order(calling_time: :desc).limit(10)
		end
		render json: $phone_history
	end
	
	def non_business
		response = Twilio::TwiML::Response.new do |r|
			r.Play "https://raw.githubusercontent.com/LingduoKong/pj_2/master/NoWorkingTimeRecord.mp3"
			r.Record :maxLength => '60', :transcribe => true, 
			:transcribeCallback=> "/send-record?id=#{params['id']}",
			:action => "/handle-record?id=#{params['id']}", :method => 'get'
		end
		render xml: response.text
	end
	
	def business
		
		# initialize all values
		if $numbers == nil
			reset_numbers
		end
		
		user = User.find_by_number(params["Caller"])
		if user.present?
			$incoming_calls[params["uuid"]]['name'] = user.last_name + " " + user.first_name[0] + "."
		else
			$incoming_calls[params["uuid"]]['name'] = "unknown caller"
		end
		
		index = 0
		$numbers.each do |number|
			if $incoming_calls[params['uuid']][number[:number]].present?
				if $incoming_calls[params['uuid']][number[:number]] == 'busy'
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
					$incoming_calls[params['uuid']][number[:number]] = 'not-busy'
					break
				else
					$incoming_calls[params['uuid']][number[:number]] = 'busy'
					index += 1
				end
			end
		end
		
		puts index
		# puts $incoming_calls

		time = TZInfo::Timezone.get('America/Chicago').now.to_i
		$incoming_calls[params['uuid']]['time'] = time
		
		if index >= $numbers.length 
			
			response = Twilio::TwiML::Response.new do |r|
				r.Dial :timeout => '10', :action => "/dial-result?uuid=#{params['uuid']}", :method => 'get', :record => 'record-from-answer' do |d|
					d.Number $call_center_number 
				end
			end
			
			$incoming_calls[params["uuid"]]['calling_number'] = '+14149302932'
			$incoming_calls[params["uuid"]]['status'] = 'calling center answers'
			
		else
			
			response = Twilio::TwiML::Response.new do |r|
				r.Dial :timeout => '10', :action => "/dial-result?uuid=#{params['uuid']}&index=#{index}", :method => 'get', :record => 'record-from-answer' do |d|
					d.Number $numbers[index][:number]
				end
			end
			
			$incoming_calls[params["uuid"]]['calling_number'] = $numbers[index][:number]
			$incoming_calls[params["uuid"]]['status'] = 'ringing'

		end
		render xml: response.text
	end
	
	def dial_result
		puts params['DialCallStatus']
		puts $incoming_calls
		
		if params['index'].present?
			index = params['index'].to_i
			$numbers[index][:isbusy].compare_and_set(true,false)
		end
		
		if params['DialCallStatus'] == 'no-answer' && params["CallStatus"] == 'completed'
			$incoming_calls[params['uuid']]['status'] = 'hang up by caller'
			Phone_call.create(
				inbound_number: params['Caller'],
				caller_name: $incoming_calls[params['uuid']]['name'],
				calling_time: $incoming_calls[params['uuid']]['time'],
				answer_number: $incoming_calls[params['uuid']]['calling_number'], 
				duration: 0,
				status: 'hang up by caller'
				)
			$incoming_calls.delete(params['uuid'])
			render nothing: true
		elsif params['DialCallStatus'] != 'completed'
			redirect_to "/business?uuid=#{params['uuid']}"
		else
			$incoming_calls[params['uuid']]['Duration'] = params['DialCallDuration']
			
			if $incoming_calls[params['uuid']]['status'] != "calling center answers"
				$incoming_calls[params['uuid']]['status'] = 'finish talking'
			end
			
			Phone_call.create(
				inbound_number: params['Caller'],
				caller_name: $incoming_calls[params['uuid']]['name'],
				calling_time: $incoming_calls[params['uuid']]['time'],
				answer_number: $incoming_calls[params['uuid']]['calling_number'], 
				duration: params['DialCallDuration'],
				status: $incoming_calls[params['uuid']]['status'],
				record_url: params['RecordingUrl']
				)
			$incoming_calls.delete(params['uuid'])
			render nothing: true
		end

		$phone_history = Phone_call.order(calling_time: :desc).limit(10)

		puts $incoming_calls
	end
	

	
	def numbers
		if $numbers == nil
			reset_numbers
		end
		render "numbers"
	end
	
	def update_numbers
		require 'concurrent'
		if !$incoming_calls.present?
			if params["passwd"] !=  Rails.application.secrets.UPDATE_PASSWD
				redirect_to "/numbers", notice: "password error"
			else
				$numbers = []
				params["numbers"].each do |nb|
					$numbers.push({number:nb, isbusy: Concurrent::Atom.new(false)})
				end
				redirect_to "/numbers", notice: "update successfully"
			end
		else
			redirect_to "/numbers", notice: "Can't not be updated now. Try it later!"
		end
	end
	
	private
	def reset_numbers
		require 'concurrent'      
		$numbers = [
			{number:'+13122928193', isbusy: Concurrent::Atom.new(false)},
			{number:'+17738928145', isbusy: Concurrent::Atom.new(false)},
		]
		$incoming_calls = {}
		# call center number:
		$call_center_number = "+13122928193"
	end
	
	def business_process
		
	end
	
end
