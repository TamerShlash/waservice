require 'bundler'
Bundler.require

at_exit do
  ## TODO add code to be executed on exit here
end

require 'sinatra'
require 'sinatra/activerecord'
require 'sinatra/config_file'

config_file File.join(__dir__, 'config', 'application.yml')
response_templates = YAML.load_file(File.join(__dir__, 'responses.yml'))


class User < ActiveRecord::Base

  validates :jid, presence: true,
                  length: {minimum: 9, maximum: 14},
                  numericality: {only_integer: true}

  has_many :conversations
  has_many :messages, through: :conversations
end

class Conversation < ActiveRecord::Base
  belongs_to :user
  has_many :messages
  delegate :jid, to: :user
end

class Message < ActiveRecord::Base
  belongs_to :conversation
  delegate :jid, to: :conversation
end


def get_user_info jid
  ## Here goes code for contacting Ahmad's api and getting the user info
  ## If the given mobile number doesn't belong to any user, the response should be {'match': false}
  ## If the number belongs to a user, the response should contain as much as possible of the following:
  # { 'match': true if the given mobile number belongs to a user. false if not,
  #   'user': { # only present if match: true
  #     'name': 'Full Name',
  #     'email': 'Email Address of the User',
  #     'phone': 'Land Phone Number if available, the one used in the ADSL line if an ADSL user',
  #     'type': 'Type of subscription, e.g ADSL 256K, ADSL 1M, Dial Up... etc.',
  #     'status': 'The status of the subscription. e.g active, suspended... etc',
  #     'jid': 'The same mobile number sent for the query'
  #   }
  # }
end

def billing_info_of jid
  ## Here goes code for contacting Ahmad's api and getting the billing info
  ## The response should contain the following:
  # {
  #   'match': true if the given mobile number belongs to a user, false if not,
  #   'user': { # only present if match: true
  #     'name': 'Full Name',
  #     'email': 'Email Address of the User',
  #     'phone': 'Land Phone Number if available, the one used in the ADSL line if an ADSL user',
  #     'type': 'Type of subscription, e.g ADSL 256K, ADSL 1M, Dial Up... etc.',
  #     'status': 'The status of the subscription. e.g active, suspended... etc',
  #     'jid': 'The same mobile number sent for the query'
  #   },
  #   'billing': {
  #     'status': 'should be "unpaid" if the user has any unpaid billings, or "paid" if he has already paid everything.',
  #     'date': 'Contains the current due date if there are unpaid billings, or the next bill date if everything is already paid'
  #   }
  # }
end

def check_availability_for phone_number
  ## Here goes code for contacting Ahmad's api and checking availability, response should contain the following:
  # {
  #   'valid': true if the phone number is valid (رقم المحافظة والمقسم صالحين), false if not valid,
  #   'status': 'The status of availability. Only present if valid is true',
  #   'place': 'The Name of the Place. Only present if valid is true'
  # }
  {type: 'text', content: response_templates['availability']['available'] % place}
  {type: 'text', content: response_templates['availability']['unavail'] % place}
end

def modem_config modem_type
  {type: 'text', content: modem_type}
end

def send_email email, message
  Pony.mail from: 'whatsapp-support@sawaisp.sy',
            to: email,
            bcc: 'whatsapp-support@sawaisp.sy',
            via: :smtp,
            reply_to: 'whatsapp-support@sawaisp.sy',
            via_options: {
                address: 'out.sawaisp.sy',
                port: '25',
#                user_name: 'whatsapp-support',
#                password: 'foobar',
#                authentication: :plain,
                domain: 'sawaisp.sy'
            }
end

def process_content content
  # Replacing Indian Numerals with Arabic Ones
  res = content.gsub('٠','0').gsub('١','1').gsub('٢','2').gsub('٣','3').gsub('٤','4')
  res = res.gsub('٥','5').gsub('٦','6').gsub('٧','7').gsub('٨','8').gsub('٩','9')
  res
end

post "/" do
  unless params[:jid] and params[:content]
    return nil
  end
  jid = params[:jid]
  content = process_content(params[:content])

  res = {type: '', content: ''}

  case content
    when '0'
      res = { type: 'text', content: response_templates['main_menu'] }
    when '1'
      res = billing_info_of jid
    when '2'
      res = {type: 'text', content: response_templates['availability']['intro']}
    when '3'
      res = {type: 'text', content: response_templates['modem']['intro']}
    when '4'
      res = {type: 'text', content: response_templates['contact']['intro']}
    when /^\d{3}-\d{7}$/i
      res = check_availability_for content
    when /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,6}\s/im
      email, body = /(^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,6})\s(.*)/im.match(content)[1,2]
    when /^modem-.{4,20}$/i
      modem_type = /^modem-(.{4,20})$/i.match(content)[1].downcase
      res = modem_config(modem_type)
    else
      res = {type: 'text', content: response_templates['other']['invalid']}
  end

  content_type :json
  res.to_json
end