require 'sms_sender_ots/message_parser'
require 'sms_sender_ots/mobile_number_normalizer'
require 'sms_sender_ots/error_codes'

module SmsSenderOts
  require "net/http"

  # According to documentation: http://docs.unifonic.apiary.io
  def self.send_sms(credentials, mobile_number, message, sender, options = nil)
    to = SmsSenderOts::MobileNumberNormalizer.normalize_number(mobile_number)
    message_normalized = SmsSenderOts::MobileNumberNormalizer.normalize_message(message)
    appsid = credentials[:password]
    http = Net::HTTP.new('api.unifonic.com', 80)
    path = '/rest/Messages/Send'
    body = "AppSid=#{appsid}&Recipient=#{to}&Body=#{message_normalized}"
    if !sender.blank?
      body += "&SenderID=#{sender}"
    end 
    headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
    response = http.post(path, body, headers)
    if response.code.to_i >= 200 && response.code.to_i < 300 && !JSON.parse(response.body)["data"].blank? &&
      (JSON.parse(response.body)["data"]["Status"] == "Sent" || JSON.parse(response.body)["data"]["Status"] == "Queued")
      return { message_id: JSON.parse(response.body)["data"]["MessageID"], code: 0 }
    else
      result = SmsSenderOts::ErrorCodes.get_error_code(JSON.parse(response.body)["errorCode"]) 
      raise result[:error]
      return result
    end
  end

  def self.get_balance(credentials)
    appsid = credentials[:password]
    http = Net::HTTP.new('api.unifonic.com', 80)
    path = '/rest/Account/GetBalance'
    body = "AppSid=#{appsid}"
    headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
    response = http.post(path, body, headers)
    if response.code.to_i >= 200 && response.code.to_i < 300 && JSON.parse(response.body)["success"] == "true"
      return { balance: JSON.parse(response.body)["data"]["Balance"].to_i, code: nil }
    else
      result = SmsSenderOts::ErrorCodes.get_error_code(JSON.parse(response.body)["errorCode"])
      raise result[:error]
      return result
    end
  end

  def self.query_message(credentials, msgid)
    appsid = credentials[:password]
    http = Net::HTTP.new('api.unifonic.com', 80)
    path = '/rest/Messages/GetMessageIDStatus'
    body = "AppSid=#{appsid}&MessageID=#{msgid}"
    headers = { 'Content-Type' => 'application/x-www-form-urlencoded' }
    response = http.post(path, body, headers)
    if response.code.to_i >= 200 && response.code.to_i < 300 && JSON.parse(response.body)["success"] == "true"
      return { result: JSON.parse(response.body)["data"]["Status"], code: 0 }
    elsif response.code.to_i >= 200 && response.code.to_i <= 300 && JSON.parse(response.body)["Status"] == "Sent"
      return { result: "Sent", code: 1 }
    else
      result = SmsSenderOts::ErrorCodes.get_error_code(JSON.parse(response.body)["errorCode"])
      raise result[:error]
      return result
    end
  end
end
