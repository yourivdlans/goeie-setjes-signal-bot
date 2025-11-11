# Goeie Setjes Signal Bot

## Build and test image locally

Install `qrencode` if you haven't got it installed

`brew install qrencode`

Build image

```bash
docker compose build
```

Link a new device with Signal

```bash
docker compose run --rm --entrypoint signal-cli bot link -n "Goeie Setjes bot development" | tee >(xargs -L 1 qrencode -t utf8)
```

Start signal bot

```bash
docker compose up
```

Load new code

```bash
docker compose down && docker compose up --build
```

## Running tests

```bash
rake test
```

## Debugging

Enter docker container

```bash
docker compose run --rm --entrypoint bash bot
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

#### Dbus documentation

See: https://github.com/AsamK/signal-cli/blob/master/man/signal-cli-dbus.5.adoc

## How to deploy to dokku for the first time

```bash
ssh dokku@server apps:create goeie-setjes-signal-bot
ssh dokku@server proxy:disable goeie-setjes-signal-bot
ssh dokku@server storage:mount goeie-setjes-signal-bot /var/lib/dokku/data/storage/goeie-setjes-signal-bot:/root/.local/share/signal-cli/data/
ssh dokku@server config:set goeie-setjes-signal-bot SIGNAL_USER_ACCOUNT=... SIGNAL_GROUP_ID=... GOEIE_SETJES_SIGNAL_BOT_API_TOKEN=...
git remote add dokku dokku@server:goeie-setjes-signal-bot
git push dokku master
```

## Link Signal account on dokku

```bash
ssh dokku@server enter goeie-setjes-signal-bot
signal-cli link -n "Goeie Setjes bot"
```

## Link Signal account on dokku when container cannot be started

```bash
ssh dokku@server docker-options:add goeie-setjes-signal-bot run "--entrypoint /usr/bin/env"
ssh dokku@server 'run goeie-setjes-signal-bot -- signal-cli link --name "Goeie Setjes bot"'
qrencode -o qrcode.png 'sgnl://linkdevice?uuid=uuid&pub_key=pub_key' && open qrcode.png
ssh dokku@server docker-options:remove goeie-setjes-signal-bot run "--entrypoint /usr/bin/env"
ssh dokku@server ps:start goeie-setjes-signal-bot
```

See: "Link a new device with Signal"

## How to deploy updates

```bash
git push dokku master
```

## How to test out features on test chat

When setting a different SIGNAL_GROUP_ID spaces need to be escaped.

```bash
ssh dokku@projects.itflows.nl config:set goeie-setjes-signal-bot SIGNAL_GROUP_ID="1\ 2\ 3\ 4\"
```
