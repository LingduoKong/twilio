module ReportsHelper
    def dateToTimeStamp(date)
        month = date[0,2].to_i
        day = date[3,5].to_i
        year = date[6,10].to_i
        return Date.new(year,month,day).to_time.to_i
    end
end
