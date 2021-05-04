require "test_helper"

require "signal_bot"

describe SignalBot do
  before do
    # Reset config
    SignalBot.config.update(SignalBot.config.pristine.to_h)
  end

  describe "when group_id does not correspond with config" do
    it "returns nil" do
      signal_bot = SignalBot.new(nil, "+31612345678", [1, 2, 3], "!help")
      _(signal_bot.handle_message).must_be_nil
    end
  end

  describe "when help is requested" do
    before do
      SignalBot.config.signal_group_id = "1 2 3"

      @help_response = "Verfügbare Befehle:\n\n!goedsetje\n!search [something]\n!stats"
    end

    it "responds with the help text for !help" do
      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [@help_response, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!help")
      signal_bot.handle_message

      signal.verify
    end

    it "responds with the help text for !hilfe" do
      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [@help_response, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!hilfe")
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

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!goedsetje")
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

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!goedsetje")
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

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!stats")
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

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!stats")
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

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!stats")
      signal_bot.handle_message

      signal.verify
    end
  end

  describe "when !search is received" do
    before do
      SignalBot.config.signal_group_id = "1 2 3"
      SignalBot.config.public_api_endpoint = "https://localhost"
    end

    it "responds with search results" do
      found_items = {}
      found_items[:data] = [
        {
          attributes: {
            "fb-name" => "an item with more than 40 characters lorum ipsum",
            "url" => "https://localhost/plays/1",
            "likes-count" => 1,
            "plays-count" => 2
          }
        },
        {
          attributes: {
            "fb-name" => "some item",
            "url" => "https://localhost/plays/2",
            "likes-count" => 3,
            "plays-count" => 4
          }
        }
      ]

      stub_request(:get, "https://localhost/api/items?filter%5Bbroken-link%5D=false&filter%5Bname%5D=something&page%5Blimit%5D=5&sort=-likes-count,-plays-count").
        with(
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
          }).
        to_return(status: 200, body: found_items.to_json)

      response_message = <<-RESPONSE
an item with more than 40 characters l... (1 ❤️ / 2 🎵)
https://localhost/plays/1

some item (3 ❤️ / 4 🎵)
https://localhost/plays/2
RESPONSE

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, [response_message.strip, [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!search something ")
      signal_bot.handle_message

      signal.verify
    end

    it "responds with a message about zero results" do
      stub_request(:get, "https://localhost/api/items?filter%5Bbroken-link%5D=false&filter%5Bname%5D=something&page%5Blimit%5D=5&sort=-likes-count,-plays-count").
        with(
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
          }).
        to_return(status: 200, body: { data: [] }.to_json)

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["ACHTUNG! Wir konnten nichts finden", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!search something ")
      signal_bot.handle_message

      signal.verify
    end

    it "responds with an error" do
      stub_request(:get, "https://localhost/api/items?filter%5Bbroken-link%5D=false&filter%5Bname%5D=something&page%5Blimit%5D=5&sort=-likes-count,-plays-count").
        with(
          headers: {
            "Accept" => "application/vnd.api+json",
            "Content-Type" => "application/vnd.api+json",
          }).
        to_return(status: 500)

      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["ACHTUNG! Ein großes Problem ist aufgetreten", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!search something ")
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
      signal.expect(:sendGroupMessage, nil, ["Du bist ein like", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!like 1")
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

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "string with url https://example.com and content")
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

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "string with url https://example.com and content")
      signal_bot.handle_message

      signal.verify
    end

    it "does not post if item contains public api endpoint" do
      signal_bot = SignalBot.new(nil, "+31612345678", [1, 2, 3], "string with url https://public-api/some-path and content")
      signal_bot.handle_message
    end
  end
end
