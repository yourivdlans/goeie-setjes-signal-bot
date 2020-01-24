# Goeie Setjes Signal Bot

Build a new image

```bash
docker build .
docker create --name signal-cli IMG_ID
```

Link a new device

```bash
docker run -it --volumes-from signal-cli --entrypoint signal-cli IMG_ID link -n "Goeie Setjes bot"
```

Start a webserver which exposes `/messages.json`

```bash
docker run --volumes-from signal-cli -p 9292:9292 -e SIGNAL_USER_ACCOUNT=... -e SIGNAL_GROUP_ID=... IMG_ID
```
