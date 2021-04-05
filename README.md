# Goeie Setjes Signal Bot

## Build and test image locally

Install `qrencode` if you haven't got it installed

`brew install qrencode`

Build image

```bash
docker-compose build
```

Link a new device with Signal

```bash
docker-compose run --rm --entrypoint signal-cli bot link -n "Goeie Setjes bot development"
```

Open a second terminal window/tab and copy/paste the `tsdevice` string from the link output into qrencode.

Scan the output with Signal to link the device.

```bash
qrencode -o qrcode.png 'tsdevice:/?uuid=uuid&pub_key=pub_key' && open qrcode.png
```

Start signal bot

```bash
docker-compose up
```

## Running tests

```bash
ruby -Ilib:test signal_bot_test.rb
```

## Debugging

Enter docker container

```bash
docker-compose run --rm --entrypoint bash bot
```

Test private Goeie Setjes API

```bash
curl --insecure -i -H "X-SIGNAL-BOT-API-TOKEN: ..." \
     -H "Accept: application/vnd.api+json" \
     -H "Content-Type: application/vnd.api+json" \
     -X POST -d '{"data": {"type":"signal_messages", "attributes":{"sender":"+316654321", "message":"Test message!"}}}' \
     https://localhost:3000/api/signal-messages
```

### Dbus

```bash
signal-cli --dbus send -m "Test!" "+31612345678"

# Get group id's as space separated hex digits
dbus-send --session --type=method_call --print-reply --dest='org.asamk.Signal' /org/asamk/Signal org.asamk.Signal.getGroupIds

# Convert Hex to Byte array
python3 -c 'print(",".join(str(x) for x in bytes.fromhex("some hex value")))'

# Get group name using byte array
dbus-send --session --type=method_call --print-reply --dest='org.asamk.Signal' /org/asamk/Signal org.asamk.Signal.getGroupName array:byte:some,byte,array

# Send message to group
dbus-send --session --type=method_call  --print-reply --dest=org.asamk.Signal /org/asamk/Signal org.asamk.Signal.sendGroupMessage  string:'Hallo?'  string:array:''  array:byte:some,byte,array
```

## How to deploy to dokku for the first time

```bash
ssh ubuntu@projects.itflows.nl
git clone git@github.com:yourivdlans/goeie-setjes-signal-bot.git ~/goeie-setjes-signal-bot
cd ~/goeie-setjes-signal-bot
sudo docker build . -t dokku/goeie-setjes-signal-bot:latest
sudo dokku tags:deploy goeie-setjes-signal-bot latest
dokku ps:rebuild goeie-setjes
dokku proxy:disable goeie-setjes-signal-bot
dokku storage:mount goeie-setjes-signal-bot /var/lib/dokku/data/storage/goeie-setjes-signal-bot:/root/.local/share/signal-cli/data/
dokku config:set goeie-setjes-signal-bot SIGNAL_USER_ACCOUNT=... SIGNAL_GROUP_ID=... GOEIE_SETJES_API=... GOEIE_SETJES_API_TOKEN=...
```

## Link Signal account on dokku

```bash
dokku enter goeie-setjes-signal-bot
signal-cli link -n "Goeie Setjes bot"
```

See: "Link a new device with Signal"

## How to update image for dokku

```bash
ssh ubuntu@projects.itflows.nl
cd ~/goeie-setjes-signal-bot
git pull
sudo docker build . -t dokku/goeie-setjes-signal-bot:latest
sudo dokku tags:deploy goeie-setjes-signal-bot latest
```
