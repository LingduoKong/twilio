class UserMailer < ApplicationMailer

	default from: 'lingduokong@gmail.com'

	def welcome_email(response)
		mail(to: 'kld.application@gmail.com', 
		  subject: 'Welcome to My Awesome Site',
		  body: response.to_s)
	end

end