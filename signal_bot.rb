require "http"
require "dry-configurable"

class SignalBot
  extend Dry::Configurable

  setting :public_api_endpoint
  setting :private_api_endpoint
  setting :private_api_token
  setting :signal_group_id

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def initialize(signal, sender, group_id, message)
    @signal = signal
    @sender = sender
    @group_id = group_id
    @message = message
  end

  def handle_message
    return if group_id != signal_group_id

    if message == "!help" || message == "!hilfe"
      help
    elsif message == "!goedsetje"
      random_item
    elsif /https?:\/\/|wwww\./.match?(message) && !message.include?(self.class.config.public_api_endpoint)
      add_item
    end
  end

  private

  attr_reader :signal, :sender, :group_id, :message

  def logger
    self.class.logger
  end

  def signal_group_id
    return if self.class.config.signal_group_id.nil?

    self.class.config.signal_group_id.split.map(&:to_i)
  end

  def help
    signal.sendGroupMessage("Verfügbare Befehle:\n\n!goedsetje", [], group_id)
  end

  def random_item
    item = get_random_item

    if item
      attributes = item.dig("data", "attributes")
      response = [attributes["fb-name"], "likes: #{attributes["likes-count"]}, plays: #{attributes["plays-count"]}", attributes["url"]].join("\n")

      signal.sendGroupMessage(response, [], group_id)
    else
      signal.sendGroupMessage("ACHTUNG! wir konnten es nicht finden", [], group_id)
    end
  end

  def add_item
    post_signal_message
  end

  def post_signal_message
    json_body = {
      data: {
        type: "signal_messages",
        attributes: {
          sender: sender,
          message: message
        }
      }
    }

    response = HTTP.headers(
      "Accept" => "application/vnd.api+json",
      "Content-Type" => "application/vnd.api+json",
      "X-SIGNAL-BOT-API-TOKEN" => self.class.config.private_api_token
    ).post(self.class.config.private_api_endpoint, json: json_body)

    if response.status.success?
      signal.sendGroupMessage("Was für eine Scheiße ist das?", [], group_id)
    else
      signal.sendGroupMessage("ACHTUNG! Ein großes Problem ist aufgetreten!", [], group_id)
    end
  end

  def get_random_item
    response = HTTP.headers(
      "Accept" => "application/vnd.api+json",
      "Content-Type" => "application/vnd.api+json",
    ).get(self.class.config.public_api_endpoint + "/api/random-item")

    JSON.parse(response.body.to_s) if response.status.success?
  rescue JSON::ParserError
    nil
  end
end
