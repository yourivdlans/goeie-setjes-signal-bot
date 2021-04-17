require "minitest/autorun"
require "webmock/minitest"
require "dry/configurable/test_interface"
require "byebug"
require "./signal_bot"

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

  describe "when !help is received" do
    before { SignalBot.config.signal_group_id = "1 2 3" }

    it "responds with the help text" do
      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["Verfügbare Befehle:\n\n!goedsetje", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!help")
      signal_bot.handle_message

      signal.verify
    end
  end

  describe "when !hilfe is received" do
    before { SignalBot.config.signal_group_id = "1 2 3" }

    it "responds with the help text" do
      signal = Minitest::Mock.new
      signal.expect(:sendGroupMessage, nil, ["Verfügbare Befehle:\n\n!goedsetje", [], [1, 2 ,3]])

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
      signal.expect(:sendGroupMessage, nil, ["ACHTUNG! wir konnten es nicht finden", [], [1, 2 ,3]])

      signal_bot = SignalBot.new(signal, "+31612345678", [1, 2, 3], "!goedsetje")
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
