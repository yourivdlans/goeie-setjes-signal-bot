require "dbus"
require "./signal_bot"

SignalBot.config.public_api_endpoint = ENV.fetch("GOEIE_SETJES_PUBLIC_API")
SignalBot.config.private_api_endpoint = ENV.fetch("GOEIE_SETJES_API")
SignalBot.config.private_api_token = ENV.fetch("GOEIE_SETJES_API_TOKEN")
SignalBot.config.signal_group_id = ENV.fetch("SIGNAL_GROUP_ID")

$stdout.sync = true
logger = SignalBot.logger

logger.info "Attaching to dbus..."

bus = DBus::SessionBus.instance
signal_service = bus.service("org.asamk.Signal")
signal = signal_service.object("/org/asamk/Signal")
signal.introspect
signal.default_iface = "org.asamk.Signal"

signal.on_signal("SyncMessageReceived") do |timestamp, sender, destination, group_id, message, _attachments|
  logger.info "Timestamp: #{timestamp}"
  logger.info "Sender: #{sender}"
  logger.info "Destination: #{destination}"
  logger.info "group_id: #{group_id}"
  logger.info "Message: #{message}"

  SignalBot.new(signal, sender, group_id, message).handle_message
end

signal.on_signal("MessageReceived") do |timestamp, sender, group_id, message, _attachments|
  logger.info "Timestamp: #{timestamp}"
  logger.info "Sender: #{sender}"
  logger.info "group_id: #{group_id}"
  logger.info "Message: #{message}"

  SignalBot.new(signal, sender, group_id, message).handle_message
end

logger.info "Signal bot running..."

loop = DBus::Main.new
loop << bus
loop.run
