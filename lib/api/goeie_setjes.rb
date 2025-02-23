class Api::GoeieSetjes
  attr_reader :response, :parsed_response

  def initialize(signal_account:, api_endpoint:, signal_bot_api_token:, logger:)
    @signal_account = signal_account
    @api_endpoint = api_endpoint
    @signal_bot_api_token = signal_bot_api_token
    @logger = logger
  end

  def create_item(url)
    json_body = {
      data: {
        type: "items",
        attributes: {
          url: url
        }
      }
    }

    post("/api/v2/items", json: json_body)
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

  def like_item(item_id)
    json_body = {
      data: {
        type: "likes",
        attributes: { item_id: item_id }
      }
    }

    post("/api/v2/likes", json: json_body)
  end

  def dislike_item(item_id)
    json_body = {
      data: {
        type: "dislikes",
        attributes: { item_id: item_id }
      }
    }

    post("/api/v2/dislikes", json: json_body)
  end

  def report_item(item_id)
    json_body = {
      data: {
        id: item_id,
        type: "items",
        attributes: {
          broken_link: true
        }
      }
    }

    patch("/api/v2/items/#{item_id}.json", json: json_body)
  end

  def success?
    response.status.success?
  end

  private

  attr_reader :signal_bot_api_token, :signal_account, :api_endpoint, :logger

  def get(path, headers: {}, params: {})
    @response = HTTP.headers(default_headers.merge(headers))
                    .get(api_endpoint + path, params: params)

    @parsed_response = parse_response(@response)

    self
  end

  def post(path, headers: {}, json: {})
    @response = HTTP.headers(default_headers.merge(headers))
                    .post(api_endpoint + path, json: json)

    @parsed_response = parse_response(@response)

    self
  end

  def patch(path, headers: {}, json: {})
    @response = HTTP.headers(default_headers.merge(headers))
                    .patch(api_endpoint + path, json: json)

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
      "X-SIGNAL-ACCOUNT" => signal_account,
      "X-SIGNAL-BOT-API-TOKEN" => signal_bot_api_token
    }
  end
end
