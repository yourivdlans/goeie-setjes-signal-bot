require "test_helper"

ENV["GOEIE_SETJES_PUBLIC_API"] ||= ""
ENV["GOEIE_SETJES_API"] ||= ""
ENV["GOEIE_SETJES_SIGNAL_BOT_API_TOKEN"] ||= ""
ENV["SIGNAL_GROUP_ID"] ||= ""

require "main"

describe Main do
  describe "when the program is started" do
    it "sets up the dbus" do
      session_bus = Minitest::Mock.new
      service = Minitest::Mock.new
      signal = Minitest::Mock.new
      dbus = Minitest::Mock.new
      dbus_instance = Minitest::Mock.new
      logger = Minitest::Mock.new

      session_bus.expect(:service, service, ["org.asamk.Signal"])
      service.expect(:object, signal, ["/org/asamk/Signal"])
      signal.expect(:introspect, nil, [])
      signal.expect(:default_iface=, nil, ["org.asamk.Signal"])
      signal.expect(:on_signal, nil, ["SyncMessageReceived"])
      signal.expect(:on_signal, nil, ["MessageReceived"])

      dbus.expect(:new, dbus_instance, [])
      dbus_instance.expect(:<<, nil, [session_bus])
      dbus_instance.expect(:run, nil, [])

      logger.expect(:info, nil, ["Attaching to dbus..."])
      logger.expect(:info, nil, ["Signal bot running..."])

      Main.new(session_bus: session_bus, dbus: dbus, logger: logger).run

      session_bus.verify
      service.verify
      signal.verify
      dbus.verify
      dbus_instance.verify
      logger.verify
    end
  end
end
