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
    elsif /^!like\s.*?/.match?(message)
      like_item(message.delete_prefix("!like").strip)
    elsif message.start_with?("!")
      unknown_command(message)
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
!search [something] [page:n]
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
    if page_number_query = query.slice!(/page:\d{1,2}/)
      page_number = page_number_query.split(":").last.to_i
    else
      page_number = 1
    end

    results = get_search_results(query.strip, page: page_number)

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

      <<-RESPONSE
#{shorten(attributes["name"], 40)} (#{attributes["likes_count"]} ❤️ / #{attributes["plays_count"]} 🎵)
#{attributes["url"]}
RESPONSE
    end.join("\n").strip

    total_count = results.dig("meta", "stats", "total", "count")

    if total_count && total_count > 5
      total_pages = (total_count / 5.0).ceil

      response << "\n\nAnzahl der Suchergebnisse: #{total_count}\nSeite: #{page_number}/#{total_pages}"
    end

    logger.info "Send search results"

    signal.sendGroupMessage(response, [], group_id)
  end

  def like_item(item_id)
    unless is_integer?(item_id)
      signal.sendGroupMessage("NEIN!", [], group_id)
      return
    end

    like_response = get_like_results(item_id)
    json_like_response = parse_json(like_response.body.to_s)

    validation_error_codes = json_like_response&.dig("errors")&.map { |error| error.dig("meta", "code") }&.compact

    if like_response.status.client_error? && validation_error_codes&.include?("blank")
      logger.info "item##{item_id} does not exists"

      signal.sendGroupMessage("Diese ID wurde nicht gefunden!", [], group_id)
    elsif like_response.status.client_error? && validation_error_codes&.include?("taken")
      logger.info "item##{item_id} already liked"

      signal.sendGroupMessage("Diese ID hat dir schon gefallen!", [], group_id)
    elsif like_response.status.success?
      logger.info "#{sender} liked #{item_id}"

      liked_item = get_item(item_id)

      return if liked_item.nil?

      attributes = liked_item.dig("data", "attributes")
      response = [attributes["name"], "likes: #{attributes["likes_count"]}, plays: #{attributes["plays_count"]}", attributes["url"]].join("\n")

      logger.info "Send liked item"

      signal.sendGroupMessage(response, [], group_id)
    else
      logger.info "#{sender} could not like item #{item_id}"

      signal.sendGroupMessage("ACHTUNG! Ein großes Problem ist aufgetreten!", [], group_id)
    end
  end

  def unknown_command(message)
    words = message.split(" ")

    return if words.length.zero?

    signal.sendGroupMessage("Du bist ein #{words[0].delete_prefix("!")}", [], group_id)
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

  def get_item(item_id)
    response = HTTP.get(self.class.config.public_api_endpoint + "/api/v2/items/#{item_id}")

    JSON.parse(response.body.to_s) if response.status.success?
  rescue JSON::ParserError
    nil
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

  def get_search_results(query, page: 1)
    response = HTTP.headers(default_headers)
                   .get(
                     self.class.config.public_api_endpoint + "/api/v2/items",
                     params: {
                       sort: "-likes_count,-plays_count",
                       "page[number]": page,
                       "page[size]": 5,
                       "filter[broken_link]": "false",
                       "filter[name][search]": query,
                       "stats[total]": "count"
                     }
                   )

    JSON.parse(response.body.to_s) if response.status.success?
  rescue JSON::ParserError
    nil
  end

  def get_like_results(item_id)
    json_body = {
      data: {
        type: "likes",
        attributes: {
          item_id: item_id
        }
      }
    }

    HTTP.headers(
      default_headers.merge({
        "X-SIGNAL-ACCOUNT" => sender
      })
    ).post(self.class.config.public_api_endpoint + "/api/v2/likes", json: json_body)
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

  def parse_json(raw)
    JSON.parse(raw)
  rescue JSON::ParserError
    logger.info "Could not parse json"

    nil
  end

  def is_integer?(obj)
    Integer(obj)

    true
  rescue ArgumentError
    false
  end
end
