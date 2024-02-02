class Api::GoeieSetjes
  attr_reader :response, :parsed_response, :signal_bot_api_token

  def initialize(base_path, logger, signal_bot_api_token)
    @base_path = base_path
    @logger = logger
    @signal_bot_api_token = signal_bot_api_token
  end

  def create_signal_message(sender, message)
    json_body = {
      data: {
        type: "signal_messages",
        attributes: {
          sender: sender,
          message: message
        }
      }
    }

    post(
      "/api/v2/signal_messages",
      headers: { "X-SIGNAL-BOT-API-TOKEN": signal_bot_api_token },
      json: json_body
    )
  end

  def get_item(item_id)
    get("/api/v2/items/#{item_id}")
  end

  def get_random_item
    get("/api/random-item")
  end

  def get_stats_results
    get("/api/v2/stats.json?include=most_liked_item,most_played_item,top_items")
  end

  def get_search_results(query, page: 1)
    get("/api/v2/items", params: {
      sort: "-likes_count,-plays_count",
      "page[number]": page,
      "page[size]": 5,
      "filter[broken_link]": "false",
      "filter[name][search]": query,
      "stats[total]": "count"
    })
  end

  def like_item(item_id, signal_account:)
    json_body = {
      data: {
        type: "likes",
        attributes: { item_id: item_id }
      }
    }

    post("/api/v2/likes", headers: { "X-SIGNAL-ACCOUNT": signal_account }, json: json_body)
  end

  def report_item(item_id, signal_account:)
    json_body = {
      data: {
        id: item_id,
        type: "items",
        attributes: {
          broken_link: true
        }
      }
    }

    patch("/api/v2/items/#{item_id}.json", headers: { "X-SIGNAL-ACCOUNT": signal_account }, json: json_body)
  end

  def success?
    response.status.success?
  end

  private

  attr_reader :base_path, :logger

  def get(path, headers: {}, params: {})
    @response = HTTP.headers(default_headers.merge(headers))
                    .get(base_path + path, params: params)

    @parsed_response = parse_response(@response)

    self
  end

  def post(path, headers: {}, json: {})
    @response = HTTP.headers(default_headers.merge(headers))
                    .post(base_path + path, json: json)

    @parsed_response = parse_response(@response)

    self
  end

  def patch(path, headers: {}, json: {})
    @response = HTTP.headers(default_headers.merge(headers))
                    .patch(base_path + path, json: json)

    @parsed_response = parse_response(@response)

    self
  end

  def parse_response(res)
    unless res.status.success?
      logger.debug "API request failed with: #{res.status}"
      logger.debug res.body.to_s
    end

    JSON.parse(res.body.to_s)
  rescue JSON::ParserError
    nil
  end

  def default_headers
    {
      "Accept" => "application/vnd.api+json",
      "Content-Type" => "application/vnd.api+json",
    }
  end
end
