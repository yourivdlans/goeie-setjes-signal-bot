require "dbus"
require "rufus-scheduler"
require "./lib/signal_bot"

SignalBot.config.public_api_endpoint = ENV.fetch("GOEIE_SETJES_PUBLIC_API")
SignalBot.config.signal_bot_api_token = ENV.fetch("GOEIE_SETJES_SIGNAL_BOT_API_TOKEN")
SignalBot.config.signal_group_id = ENV.fetch("SIGNAL_GROUP_ID")

$stdout.sync = true

class Main
  def initialize(session_bus: DBus::SessionBus.instance, dbus: DBus::Main, logger: SignalBot.logger, scheduler: Rufus::Scheduler.new)
    @session_bus = session_bus
    @dbus = dbus
    @logger = logger
    @scheduler = scheduler
  end

  def run
    logger.info "Attaching to dbus..."

    setup
  end

  private

  attr_reader :session_bus, :dbus, :signal, :logger, :scheduler

  def setup
    retries ||= 0

    signal_service = session_bus.service("org.asamk.Signal")
    @signal = signal_service.object("/org/asamk/Signal")
    @signal.introspect
    @signal.default_iface = "org.asamk.Signal"

    handle_messages
    schedule_weekly_party_message
    start_loop
  rescue DBus::Error
    sleep 1

    logger.info "Retry attempt ##{retries + 1}, still trying to attach to dbus..."

    retry if (retries += 1) < 120
  end

  def schedule_weekly_party_message
    scheduler.cron("0 17 * * 5 Europe/Amsterdam") do
      SignalBot.new(signal, nil, SignalBot.configured_group_id, nil, nil).send_weekly_party_message
    end
  end

  def handle_messages
    signal.on_signal("SyncMessageReceived") do |timestamp, sender, destination, group_id, message, _attachments|
      logger.info "Timestamp: #{timestamp}"
      logger.info "Sender: #{sender}"
      logger.info "Destination: #{destination}"
      logger.info "group_id: #{group_id}"
      logger.info "Message: #{message}"

      SignalBot.new(signal, sender, group_id, message, timestamp).handle_message
    end

    signal.on_signal("MessageReceived") do |timestamp, sender, group_id, message, _attachments|
      logger.info "Timestamp: #{timestamp}"
      logger.info "Sender: #{sender}"
      logger.info "group_id: #{group_id}"
      logger.info "Message: #{message}"

      SignalBot.new(signal, sender, group_id, message, timestamp).handle_message
    end
  end

  def start_loop
    logger.info "Signal bot running..."

    loop = dbus.new
    loop << session_bus
    loop.run
  end
end

Main.new.run if ENV.fetch("TEST", false) == false
