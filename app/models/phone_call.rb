class Phone_call < ActiveRecord::Base
    validates :inbound_number ,presence: true
end
