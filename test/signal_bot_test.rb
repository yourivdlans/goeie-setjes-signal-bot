require "test_helper"

require "signal_bot"

describe SignalBot do
  before do
    # Reset config
    SignalBot.config.update(SignalBot.config.pristine.to_h)
  end

  describe "when group_id does not correspond with config" do
    it "returns nil" do
      signal_bot = SignalBot.new(nil, "+31612345678", [1, 2, 3], "!help", 123456789)
      _(signal_bot.handle_message).must_be_nil
    end
  end

  describe "when help is requested" do
    before do
      SignalBot.config.signal_group_id = "1 2 3"

      @help_response = "Verfügbare Befehle:\n\n!goedsetje\n!search [something] [page:n]\n!like [n]\n!report [n]\n!stats"
    end

    it "responds with the help text for !help" do
      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [@help_response, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!help", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with the help text for !hilfe" do
      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [@help_response, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!hilfe", 123456789)
      signal_bot.handle_message

      signal.verify
    end
  end

  describe "when !goedsetje is received" do
    before do
      SignalBot.config.signal_group_id = "1 2 3"
      SignalBot.config.public_api_endpoint = "http://localhost"
    end

    it "responds with a random item" do
      random_item = {
        data: {
          attributes: {
            "fb-name" => "some item",
            "likes-count" => "2",
            "plays-count" => "3",
            "url" => "https://localhost/plays/1"
          }
        }
      }

      stub_request(:get, "http://localhost/api/random-item").
        with(
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json"
          }).
        to_return(status: 200, body: random_item.to_json)

      response_message = "some item\nlikes: 2, plays: 3\nhttps://localhost/plays/1"

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [response_message, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!goedsetje", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with an error message" do
      stub_request(:get, "http://localhost/api/random-item").
        with(
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json"
          }).
        to_return(status: 500)

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["ACHTUNG! Ein großes Problem ist aufgetreten", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!goedsetje", 123456789)
      signal_bot.handle_message

      signal.verify
    end
  end

  describe "when !stats is received" do
    before do
      SignalBot.config.signal_group_id = "1 2 3"
      SignalBot.config.public_api_endpoint = "https://localhost"
    end

    it "responds with stats results" do
      stats_results = {}
      stats_results[:data] = {
        likes_count: 10,
        plays_count: 20,
        top_items: [
          {
            url: "https://example.com/some-item",
            name: "Some item",
            likes_count: 5,
            plays_count: 6
          },
          {
            url: "https://example.com/some-other-item",
            name: "Some other item",
            likes_count: 2,
            plays_count: 7
          }
        ]
      }

      stub_request(:get, "https://localhost/api/v2/stats.json?include=most_liked_item,most_played_item,top_items").
        with(
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
          }).
        to_return(status: 200, body: stats_results.to_json)

      response_message = <<-RESPONSE
Total 10 ❤️
Total 20 🎵

Top 5:
1. Some item (5 ❤️ / 6 🎵)
https://example.com/some-item

2. Some other item (2 ❤️ / 7 🎵)
https://example.com/some-other-item
RESPONSE

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [response_message.strip, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!stats", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with a message when an error was returned" do
      stub_request(:get, "https://localhost/api/v2/stats.json?include=most_liked_item,most_played_item,top_items").
        with(
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
          }).
        to_return(status: 500)

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["ACHTUNG! Ein großes Problem ist aufgetreten", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!stats", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with a message when there were no attributes" do
      stub_request(:get, "https://localhost/api/v2/stats.json?include=most_liked_item,most_played_item,top_items").
        with(
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
          }).
        to_return(status: 200, body: { data: {} }.to_json)

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["ACHTUNG! Ein großes Problem ist aufgetreten", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!stats", 123456789)
      signal_bot.handle_message

      signal.verify
    end
  end

  describe "when !search is received" do
    before do
      SignalBot.config.signal_group_id = "1 2 3"
      SignalBot.config.public_api_endpoint = "https://localhost"

      @search_result = {}
      @search_result[:data] = [
        {
          attributes: {
            "name" => "an item with more than 40 characters lorum ipsum",
            "url" => "https://localhost/plays/1",
            "likes_count" => 1,
            "plays_count" => 2
          }
        },
        {
          attributes: {
            "name" => "some item",
            "url" => "https://localhost/plays/2",
            "likes_count" => 3,
            "plays_count" => 4
          }
        }
      ]
    end

    it "responds with search results" do
      stub_request(:get, "https://localhost/api/v2/items?filter%5Bbroken_link%5D=false&filter%5Bname%5D%5Bsearch%5D=something&page%5Bnumber%5D=1&page%5Bsize%5D=5&sort=-likes_count,-plays_count&stats%5Btotal%5D=count").
        with(
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
          }).
        to_return(status: 200, body: @search_result.to_json)

      response_message = <<-RESPONSE
an item with more than 40 characters l... (1 ❤️ / 2 🎵)
https://localhost/plays/1

some item (3 ❤️ / 4 🎵)
https://localhost/plays/2
RESPONSE

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [response_message.strip, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!search something ", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with total amount of results and page info" do
      @search_result[:meta] = {
        stats: {
          total: {
            count: 39
          }
        }
      }

      stub_request(:get, "https://localhost/api/v2/items?filter%5Bbroken_link%5D=false&filter%5Bname%5D%5Bsearch%5D=something&page%5Bnumber%5D=2&page%5Bsize%5D=5&sort=-likes_count,-plays_count&stats%5Btotal%5D=count").
        with(
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
          }).
        to_return(status: 200, body: @search_result.to_json)

      response_message = <<-RESPONSE
an item with more than 40 characters l... (1 ❤️ / 2 🎵)
https://localhost/plays/1

some item (3 ❤️ / 4 🎵)
https://localhost/plays/2

Anzahl der Suchergebnisse: 39
Seite: 2/8
RESPONSE

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [response_message.strip, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!search something page:2", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with a message about zero results" do
      stub_request(:get, "https://localhost/api/v2/items?filter%5Bbroken_link%5D=false&filter%5Bname%5D%5Bsearch%5D=something&page%5Bnumber%5D=1&page%5Bsize%5D=5&sort=-likes_count,-plays_count&stats%5Btotal%5D=count").
        with(
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
          }).
        to_return(status: 200, body: { data: [] }.to_json)

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["ACHTUNG! Wir konnten nichts finden", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!search something ", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with an error" do
      stub_request(:get, "https://localhost/api/v2/items?filter%5Bbroken_link%5D=false&filter%5Bname%5D%5Bsearch%5D=something&page%5Bnumber%5D=1&page%5Bsize%5D=5&sort=-likes_count,-plays_count&stats%5Btotal%5D=count").
        with(
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
          }).
        to_return(status: 500)

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["ACHTUNG! Ein großes Problem ist aufgetreten", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!search something ", 123456789)
      signal_bot.handle_message

      signal.verify
    end
  end

  describe "when !like is received" do
    before do
      SignalBot.config.signal_group_id = "1 2 3"
      SignalBot.config.public_api_endpoint = "https://localhost"

      @liked_item = {
        data: {
          attributes: {
            "name" => "some item",
            "likes_count" => "2",
            "plays_count" => "3",
            "url" => "https://localhost/plays/1"
          }
        }
      }
    end

    it "likes an item" do
      stub_request(:post, "https://localhost/api/v2/likes").
        with(
          body: "{\"data\":{\"type\":\"likes\",\"attributes\":{\"item_id\":\"1\"}}}",
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
            "X-Signal-Account" => "+31612345678"
          }).
        to_return(status: 200)

      stub_request(:get, "https://localhost/api/v2/items/1").
        to_return(status: 200, body: @liked_item.to_json)

      response_message = "some item\nlikes: 2, plays: 3\nhttps://localhost/plays/1"

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [response_message.strip, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!like 1", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with error if already liked" do
      error_response = {
        errors: [
          {
            meta: {
              code: "taken"
            }
          }
        ]
      }

      stub_request(:post, "https://localhost/api/v2/likes").
        with(
          body: "{\"data\":{\"type\":\"likes\",\"attributes\":{\"item_id\":\"1\"}}}",
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
            "X-Signal-Account" => "+31612345678"
          }).
        to_return(status: 422, body: error_response.to_json)

      response_message = "Diese ID hat dir schon gefallen!"

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [response_message.strip, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!like 1", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with error if item does not exist" do
      error_response = {
        errors: [
          {
            meta: {
              code: "blank"
            }
          }
        ]
      }

      stub_request(:post, "https://localhost/api/v2/likes").
        with(
          body: "{\"data\":{\"type\":\"likes\",\"attributes\":{\"item_id\":\"1\"}}}",
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
            "X-Signal-Account" => "+31612345678"
          }).
        to_return(status: 422, body: error_response.to_json)

      response_message = "Diese ID wurde nicht gefunden!"

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [response_message.strip, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!like 1", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with error for invalid item id" do
      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["NEIN!", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!like n", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with generic error" do
      stub_request(:post, "https://localhost/api/v2/likes").
        to_return(status: 500)

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["ACHTUNG! Ein großes Problem ist aufgetreten!", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!like 1", 123456789)
      signal_bot.handle_message

      signal.verify
    end
  end

  describe "when !report is received" do
    before do
      SignalBot.config.signal_group_id = "1 2 3"
      SignalBot.config.public_api_endpoint = "https://localhost"

      @reported_item = {
        data: {
          attributes: {
            name: "some item",
            broken_link: true
          }
        }
      }
    end

    it "reports an item" do
      stub_request(:patch, "https://localhost/api/v2/items/1.json").
        with(
          body: "{\"data\":{\"id\":\"1\",\"type\":\"items\",\"attributes\":{\"broken_link\":true}}}",
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
            "X-Signal-Account" => "+31612345678"
          }).
        to_return(status: 200)

      response_message = "Raus mit dieser verdammten Scheiße!"

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [response_message.strip, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!report 1", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with error if item does not exist" do
      stub_request(:patch, "https://localhost/api/v2/items/1.json").
        with(
          body: "{\"data\":{\"id\":\"1\",\"type\":\"items\",\"attributes\":{\"broken_link\":true}}}",
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
            "X-Signal-Account" => "+31612345678"
          }).
        to_return(status: 404)

      response_message = "ACHTUNG! Ein großes Problem ist aufgetreten!"

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [response_message.strip, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!report 1", 123456789)
      signal_bot.handle_message

      signal.verify
    end
  end

  describe "when an unknown command is received" do
    before do
      SignalBot.config.signal_group_id = "1 2 3"
    end

    it "responds with message" do
      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["Du bist ein unlike", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!unlike 1", 123456789)
      signal_bot.handle_message

      signal.verify
    end
  end

  describe "when a message with a url is received" do
    before do
      SignalBot.config.signal_group_id = "1 2 3"
      SignalBot.config.public_api_endpoint = "https://public-api"
      SignalBot.config.private_api_endpoint = "https://localhost"
      SignalBot.config.private_api_token = "some-token"
    end

    it "posts item to api and responds with message" do
      stub_request(:post, "https://localhost/").
        with(
          body: "{\"data\":{\"type\":\"signal_messages\",\"attributes\":{\"sender\":\"+31612345678\",\"message\":\"string with url https://example.com and content\"}}}",
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
            "X-SIGNAL-BOT-API-TOKEN" => "some-token"
          }).
        to_return(status: 200)

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["Was für eine Scheiße ist das?", [], [1, 2 ,3]])
      signal.expect(:sendGroupMessageReaction, nil) do |emoji, remove_reaction, target_author, target_sent_timestamp, group_id|
        SignalBot::NEW_ITEM_REACTIONS.include?(emoji) &&
          remove_reaction == false &&
          target_author == "+31612345678" &&
          target_sent_timestamp == 123456789 &&
          group_id == [1, 2, 3]
      end

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "string with url https://example.com and content", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "responds with an error message" do
      stub_request(:post, "https://localhost/").
        with(
          body: "{\"data\":{\"type\":\"signal_messages\",\"attributes\":{\"sender\":\"+31612345678\",\"message\":\"string with url https://example.com and content\"}}}",
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
            "X-SIGNAL-BOT-API-TOKEN" => "some-token"
          }).
        to_return(status: 500)

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["ACHTUNG! Ein großes Problem ist aufgetreten!", [], [1, 2 ,3]])
      signal.expect(:sendGroupMessageReaction, nil, ["\u{26A0}", false, "+31612345678", 123456789, [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "string with url https://example.com and content", 123456789)
      signal_bot.handle_message

      signal.verify
    end

    it "does not post if item contains public api endpoint" do
      signal_bot = SignalBot.new(nil, "+31612345678", [1, 2, 3], "string with url https://public-api/some-path and content", 123456789)
      signal_bot.handle_message
    end
  end
end
