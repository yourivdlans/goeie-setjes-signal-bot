# Goeie Setjes Signal Bot

## Build and test image locally

Install `qrencode` if you haven't got it installed

`brew install qrencode`

Build image

```bash
docker build . -t goeie-setjes/bot:latest
docker create --name goeie-setjes-signal-bot goeie-setjes/bot:latest
```

Link a new device

```bash
docker run -it --volumes-from goeie-setjes-signal-bot --entrypoint signal-cli goeie-setjes/bot:latest link -n "Goeie Setjes bot"
```

Open a second terminal window/tab and copy/paste the `tsdevice` string from the link output into qrencode.

Scan the output with Signal to link the device.

```bash
qrencode -o qrcode.png 'tsdevice:/?uuid=uuid&pub_key=pub_key' & open qrcode.png
```

Start a webserver which exposes `/messages.json`

```bash
docker run --volumes-from goeie-setjes-signal-bot -p 9292:9292 -e SIGNAL_USER_ACCOUNT=... -e SIGNAL_GROUP_ID=... goeie-setjes/bot:latest
```

## How to deploy to dokku for the first time

```bash
ssh ubuntu@server
git clone git@github.com:yourivdlans/goeie-setjes-signal-bot.git ~/goeie-setjes-signal-bot
cd ~/goeie-setjes-signal-bot
sudo docker build . -t dokku/goeie-setjes-signal-bot:latest
sudo dokku tags:deploy goeie-setjes-signal-bot latest
dokku docker-options:add goeie-setjes deploy "--link goeie-setjes-signal-bot.web.1:goeie-setjes"
dokku docker-options:add goeie-setjes run "--link goeie-setjes-signal-bot.web.1:goeie-setjes"
dokku ps:rebuild goeie-setjes
dokku proxy:disable goeie-setjes-signal-bot
dokku storage:mount goeie-setjes-signal-bot /var/lib/dokku/data/storage/goeie-setjes-signal-bot:/root/.local/share/signal-cli/data/
dokku config:set goeie-setjes-signal-bot SIGNAL_USER_ACCOUNT=... SIGNAL_GROUP_ID=...
```

## How to update image for dokku

```bash
ssh ubuntu@server
cd ~/goeie-setjes-signal-bot
git pull
sudo docker build . -t dokku/goeie-setjes-signal-bot:latest
sudo dokku tags:deploy goeie-setjes-signal-bot latest
```
