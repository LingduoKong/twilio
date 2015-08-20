class ReportsController < ApplicationController
    def statistics
        tz = TZInfo::Timezone.get('America/Chicago')
        @total_call_numbers={}
        if params["days"].present?
            if params["days"] == '10'
                data_history = Phone_call.where("calling_time >= ?", (tz.now - 10.days).to_i)
            elsif params["days"] == '30'
                data_history = Phone_call.where("calling_time >= ?", (tz.now - 30.days).to_i)
            end
        else
            data_history = Phone_call
        end
        @users_avg_duration = data_history.group("answer_number")
        @call_status = data_history.group("status","answer_number").order("answer_number")
        @users_avg_duration.each do |user|
            @total_call_numbers[user] = data_history.where("answer_number = ?", user["answer_number"]).count
            avg = data_history.where("answer_number = ?", user["answer_number"]).average("duration")
            user.duration = avg.to_f.round(2)
        end
        total = data_history.count * 1.0
        @call_status.each do |call|
            count = (data_history.where("answer_number = ? AND status = ?", call.answer_number, call.status).count) * 1.0
            call.duration = (count/total * 100).round(2)
        end
    
    end
    
    def history_stats
        per_page = 10 
        
        if params[:caller_name].present? || params[:caller_number].present? || params[:answer_number].present?
            @result = Phone_call.where("caller_name LIKE ?", "%#{params[:caller_name]}%")
            @result = @result.where("inbound_number LIKE ?", "%#{params[:caller_number]}%")
            @result = @result.where("answer_number LIKE ?", "%#{params[:answer_number]}%")
        else
            @result = Phone_call
        end
        
        if params[:from].present?
            @result = @result.where("calling_time >= ?", dateToTimeStamp(params[:from]))
        end
        
        if params[:to].present?
            @result = @result.where("calling_time <= ?", dateToTimeStamp(params[:to]))
        end
        
        if params[:status].present? && params[:status] != "All status"
            @result = @result.where("status = ?", params[:status])
        end
        
        @page_number = @result.count / per_page.to_i + 1

        if params["page"].present?
            puts offset = ( params["page"].to_i - 1 ) * per_page
            @current_page = params["page"].to_i
            @history_data = @result.order(calling_time: :desc).limit(per_page).offset(offset)
        else
            @current_page = 1
            @history_data = @result.order(calling_time: :desc).limit(per_page)
        end
        @page_url = "/reports/history_stats?from=#{params[:from]}&to=#{params[:to]}&status=#{params[:status]}&"
        @page_url += "caller_name=#{params[:caller_name]}&caller_number=#{params[:caller_number]}&answer_number=#{params[:answer_number]}&"
    
        @names = Phone_call.pluck("DISTINCT caller_name")
        @inbound_number = Phone_call.pluck("DISTINCT inbound_number")
        @answer_number = Phone_call.pluck("DISTINCT answer_number")
        
    end
    
    private
    def filter_params
      params.require(:filter).permit(:days)
    end
    
    def dateToTimeStamp(date)
        month = date[0,2].to_i
        day = date[3,5].to_i
        year = date[6,10].to_i
        return Date.new(year,month,day).to_time.to_i
    end
    
end
