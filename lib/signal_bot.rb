require "http"
require "logger"
require "dry-configurable"
require "./lib/url_regex"
require "./lib/api/base"
require "./lib/api/goeie_setjes"

class SignalBot
  extend Dry::Configurable

  setting :public_api_endpoint
  setting :signal_bot_api_token
  setting :signal_group_id

  NEW_ITEM_REACTIONS = [
    "\u{1F3B5}", # music note
    "\u{1F3B6}", # multiple music notes
    "\u{1F3A7}", # headphones
    "\u{1F4FB}", # radio
    "\u{1F3B9}", # keyboard
    "\u{1F941}", # drums
    "\u{1F483}", # female dancer
    "\u{1F57A}", # male dancer
    "\u{1F3B8}", # guitar
    "\u{1F4E3}", # megaphone
    "\u{1F989}", # owl
    "\u{1F4BD}", # minidisk
  ]

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end

  def initialize(signal, sender, group_id, message, timestamp)
    @signal = signal
    @sender = sender
    @group_id = group_id
    @message = message
    @timestamp = timestamp
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
    elsif /^!report\s.*?/.match?(message)
      report_item(message.delete_prefix("!report").strip)
    elsif message.start_with?("!")
      unknown_command(message)
    elsif /https?:\/\/|wwww\./.match?(message) && !message.include?(self.class.config.public_api_endpoint)
      add_item
    # else
    #   code_point = message.to_i(16)
    #   emoji = code_point.chr(Encoding::UTF_8)

    #   signal.sendGroupMessageReaction(emoji, false, sender, timestamp, group_id)
    end
  end

  private

  attr_reader :signal, :sender, :group_id, :message, :timestamp

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
!like [n]
!report [n]
!stats
HELP

    signal.sendGroupMessage(response.strip, [], group_id)
  end

  def random_item
    random_item = api.get_random_item

    if random_item.success?
      attributes = random_item.parsed_response.dig("data", "attributes")
      response = [attributes["fb-name"], "likes: #{attributes["likes-count"]}, plays: #{attributes["plays-count"]}", attributes["url"]].join("\n")

      logger.info "Send random item"

      signal.sendGroupMessage(response, [], group_id)
    else
      logger.info "Random item could not be sent"

      signal.sendGroupMessage("ACHTUNG! Ein großes Problem ist aufgetreten", [], group_id)
    end
  end

  def stats
    request = api.get_stats_results
    results = request.parsed_response

    if !request.success? || results["data"].empty?
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

    request = api.get_search_results(query.strip, page: page_number)
    results = request.parsed_response

    unless request.success?
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

    like_request = api.like_item(item_id)
    like_response = like_request.response
    json_like_response = like_request.parsed_response

    validation_error_codes = json_like_response&.dig("errors")&.map { |error| error.dig("meta", "code") }&.compact

    if like_response.status.client_error? && validation_error_codes&.include?("blank")
      logger.info "item##{item_id} does not exists"

      signal.sendGroupMessage("Diese ID wurde nicht gefunden!", [], group_id)
    elsif like_response.status.client_error? && validation_error_codes&.include?("taken")
      logger.info "item##{item_id} already liked"

      signal.sendGroupMessage("Diese ID hat dir schon gefallen!", [], group_id)
    elsif like_response.status.success?
      logger.info "#{sender} liked #{item_id}"

      liked_item = api.get_item(item_id)

      return unless liked_item.success?

      attributes = liked_item.parsed_response.dig("data", "attributes")
      response = [attributes["name"], "likes: #{attributes["likes_count"]}, plays: #{attributes["plays_count"]}", attributes["url"]].join("\n")

      logger.info "Send liked item"

      signal.sendGroupMessage(response, [], group_id)
    else
      logger.info "#{sender} could not like item #{item_id}"

      signal.sendGroupMessage("ACHTUNG! Ein großes Problem ist aufgetreten!", [], group_id)
    end
  end

  def report_item(item_id)
    unless is_integer?(item_id)
      signal.sendGroupMessage("NEIN!", [], group_id)
      return
    end

    report_request = api.report_item(item_id)

    if report_request.success?
      signal.sendGroupMessage("Raus mit dieser verdammten Scheiße!", [], group_id)
    else
      logger.info "error when updating item##{item_id}"

      signal.sendGroupMessage("ACHTUNG! Ein großes Problem ist aufgetreten!", [], group_id)
    end
  end

  def unknown_command(message)
    words = message.split(" ")

    return if words.length.zero?

    signal.sendGroupMessage("Du bist ein #{words[0].delete_prefix("!")}", [], group_id)
  end

  def api
    Api::GoeieSetjes.new(
      signal_account: sender,
      api_endpoint: self.class.config.public_api_endpoint,
      signal_bot_api_token: self.class.config.signal_bot_api_token,
      logger: self.class.logger
    )
  end

  def add_item
    url_from_message = message.match(UrlRegex.for_finding_urls).to_s
    request = api.create_item(url_from_message)
    response = request.parsed_response

    if request.success?
      logger.info "New item created"

      success_response = <<-SUCCESS
Was für eine Scheiße ist das?

#{response.dig("data", "attributes", "url")}
SUCCESS

      signal.sendGroupMessage(success_response.strip, [], group_id)
      signal.sendGroupMessageReaction(NEW_ITEM_REACTIONS.sample, false, sender, timestamp, group_id)

      # Automatically like added item
      api.like_item(response.dig("data", "id"))
    else
      logger.info "New item could not be created"

      signal.sendGroupMessage("ACHTUNG! Ein großes Problem ist aufgetreten!", [], group_id)
      signal.sendGroupMessageReaction("\u{26A0}", false, sender, timestamp, group_id)
    end
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

  def is_integer?(obj)
    Integer(obj)

    true
  rescue ArgumentError
    false
  end
end
