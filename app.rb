require 'sinatra'

class GoeieSetjesSignalBotApp < Sinatra::Base
  get '/messages.json' do
    content_type :json

    messages = %x[signal-cli -u #{ENV.fetch('SIGNAL_USER_ACCOUNT')} receive --json]

    exposed_messages = messages.split("\n").map do |message|
      json_message = JSON.parse(message)

      group_id = json_message.dig('envelope', 'dataMessage', 'groupInfo', 'groupId') || json_message.dig('envelope', 'syncMessage', 'sentMessage', 'groupInfo', 'groupId')
      next if group_id.nil? || group_id == '' || group_id != ENV.fetch('SIGNAL_GROUP_ID')

      json_message.to_json
    end.compact

    return {}.to_json if exposed_messages.length == 0

    exposed_messages.join("\n")
  end
end
