require "http"
require "logger"
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
    if group_id != signal_group_id
      logger.info "Did not receive message from configured group"
      return
    end

    if message == "!help" || message == "!hilfe"
      help
    elsif message == "!goedsetje"
      random_item
    elsif message == "!stats"
      stats
    elsif /^!search\s.*?/.match?(message)
      search_items(message.delete_prefix("!search").strip)
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
    logger.info "Send help message"

    response = <<-HELP
Verfügbare Befehle:

!goedsetje
!search [something]
!stats
HELP

    signal.sendGroupMessage(response.strip, [], group_id)
  end

  def random_item
    item = get_random_item

    if item
      attributes = item.dig("data", "attributes")
      response = [attributes["fb-name"], "likes: #{attributes["likes-count"]}, plays: #{attributes["plays-count"]}", attributes["url"]].join("\n")

      logger.info "Send random item"

      signal.sendGroupMessage(response, [], group_id)
    else
      logger.info "Random item could not be sent"

      signal.sendGroupMessage("ACHTUNG! Ein großes Problem ist aufgetreten", [], group_id)
    end
  end

  def stats
    results = get_stats_results

    if results.nil? || results["data"].empty?
      logger.info "Stats returned an error"

      signal.sendGroupMessage("ACHTUNG! Ein großes Problem ist aufgetreten", [], group_id)
      return
    end

    data = results["data"]
    top_items = data["top_items"]

    stats_response = "Total #{data["likes_count"]} ❤️\nTotal #{data["plays_count"]} 🎵"

    if !top_items.nil? && top_items.length.positive?
      top_items_response = top_items.map.with_index do |item, index|
        <<-TOPITEM
#{index+1}. #{shorten(item["name"], 40)} (#{item["likes_count"]} ❤️ / #{item["plays_count"]} 🎵)
#{item["url"]}
TOPITEM
      end.join("\n")

      stats_response += "\n\nTop 5:\n" + top_items_response.strip
    end

    logger.info "Send stats results"

    signal.sendGroupMessage(stats_response, [], group_id)
  end

  def search_items(query)
    results = get_search_results(query)

    if results.nil?
      logger.info "Search returned an error"

      signal.sendGroupMessage("ACHTUNG! Ein großes Problem ist aufgetreten", [], group_id)
      return
    end

    data = results["data"]

    if data.length.zero?
      logger.info "Search retrieved zero results"

      signal.sendGroupMessage("ACHTUNG! Wir konnten nichts finden", [], group_id)
      return
    end

    response = data.map do |item|
      attributes = item["attributes"]

      "#{shorten(attributes["fb-name"], 40)} - #{attributes["url"]}"
    end

    logger.info "Send search results"

    signal.sendGroupMessage(response.join("\n"), [], group_id)
  end

  def add_item
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
      default_headers.merge({
        "X-SIGNAL-BOT-API-TOKEN" => self.class.config.private_api_token
      })
    ).post(self.class.config.private_api_endpoint, json: json_body)

    if response.status.success?
      logger.info "New item created"

      signal.sendGroupMessage("Was für eine Scheiße ist das?", [], group_id)
    else
      logger.info "New item could not be created"

      signal.sendGroupMessage("ACHTUNG! Ein großes Problem ist aufgetreten!", [], group_id)
    end
  end

  def get_random_item
    response = HTTP.headers(default_headers)
                   .get(self.class.config.public_api_endpoint + "/api/random-item")

    JSON.parse(response.body.to_s) if response.status.success?
  rescue JSON::ParserError
    nil
  end

  def get_stats_results
    response = HTTP.headers(default_headers)
                   .get(self.class.config.public_api_endpoint + "/api/v2/stats.json?include=most_liked_item,most_played_item,top_items")

    JSON.parse(response.body.to_s) if response.status.success?
  rescue JSON::ParserError
    nil
  end

  def get_search_results(query)
    response = HTTP.headers(default_headers)
                   .get(
                     self.class.config.public_api_endpoint + "/api/items",
                     params: {
                       sort: "-likes-count,-plays-count",
                       "page[limit]": 5,
                       "filter[broken-link]": "false",
                       "filter[name]": query
                     }
                   )

    JSON.parse(response.body.to_s) if response.status.success?
  rescue JSON::ParserError
    nil
  end

  def shorten(string, length)
    return string if string.length <= length

    string[0..(length - 3)].strip + "..."
  end

  def default_headers
    {
      "Accept" => "application/vnd.api+json",
      "Content-Type" => "application/vnd.api+json",
    }
  end
end
