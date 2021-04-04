require "dbus"
require "http"

raise "Missing API url" if ENV["GOEIE_SETJES_API"].nil?
raise "Missing API token" if ENV["GOEIE_SETJES_API_TOKEN"].nil?
raise "Missing signal group id" if ENV["SIGNAL_GROUP_ID"].nil?

$stdout.sync = true
logger = Logger.new(STDOUT)

logger.info "Attaching to dbus..."

bus = DBus::SessionBus.instance
signal_service = bus.service("org.asamk.Signal")
signal = signal_service.object("/org/asamk/Signal")
signal.introspect
signal.default_iface = "org.asamk.Signal"

def post_signal_message(signal, group_id, sender, message)
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
                    "X-SIGNAL-BOT-API-TOKEN" => ENV["GOEIE_SETJES_API_TOKEN"]
                  ).post(ENV["GOEIE_SETJES_API"], json: json_body)

  if response.status.success?
    signal.sendGroupMessage("Was für eine Scheiße ist das? ", [], group_id)
  end
end

def handle_message(signal, group_id, sender, message)
  return if group_id != ENV["SIGNAL_GROUP_ID"].split.map(&:to_i)

  if message == "!help" || message == "!hilfe"
    signal.sendGroupMessage("Verfügbare Befehle:\n\n!goedsetje", [], group_id)
  end

  if message == "!goedsetje"
    signal.sendGroupMessage("https://www.youtube.com/watch?v=dQw4w9WgXcQ", [], group_id)
  end

  if /https?:\/\/|wwww\./.match?(message)
    post_signal_message(signal, group_id, sender, message)
  end
end

signal.on_signal("SyncMessageReceived") do |timestamp, sender, destination, group_id, message, _attachments|
  logger.info "Timestamp: #{timestamp}"
  logger.info "Sender: #{sender}"
  logger.info "Destination: #{destination}"
  logger.info "group_id: #{group_id}"
  logger.info "Message: #{message}"

  handle_message(signal, group_id, sender, message)
end

signal.on_signal("MessageReceived") do |timestamp, sender, group_id, message, _attachments|
  logger.info "Timestamp: #{timestamp}"
  logger.info "Sender: #{sender}"
  logger.info "group_id: #{group_id}"
  logger.info "Message: #{message}"

  handle_message(signal, group_id, sender, message)
end

logger.info "Signal bot running..."

loop = DBus::Main.new
loop << bus
loop.run
