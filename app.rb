require 'sinatra'
require 'open3'

class GoeieSetjesSignalBotApp < Sinatra::Base
  configure :production, :development do
    enable :logging
  end

  get '/messages.json' do
    content_type :json

    cmd = "signal-cli -u #{ENV.fetch('SIGNAL_USER_ACCOUNT')} receive --json"

    exposed_messages = []

    Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
      while line = stdout.gets
        logger.info(line)

        json_message = parse_line_to_json(line)
        next if json_message.nil?

        group_id = json_message.dig('envelope', 'dataMessage', 'groupInfo', 'groupId') || json_message.dig('envelope', 'syncMessage', 'sentMessage', 'groupInfo', 'groupId')
        next if group_id.nil? || group_id == '' || group_id != ENV.fetch('SIGNAL_GROUP_ID')

        exposed_messages << json_message.to_json
      end
    end

    return {}.to_json if exposed_messages.length == 0

    exposed_messages.join("\n")
  end

  def parse_line_to_json(line)
    JSON.parse(line)
  rescue JSON::ParserError
    logger.info("Failed to parse line to json")

    nil
  end
end
