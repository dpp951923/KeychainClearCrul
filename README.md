# KeychainClearCrul

KeychainClear with an HTTP control channel instead of Unix Socket.

HTTP server: `127.0.0.1:18765`

```sh
python3 control.py ping
python3 control.py status
python3 control.py clear
```

Endpoints:

```text
GET  /ping
GET  /status
POST /clear
```

Change `KeychainClearCrul_FILTER` in `Makefile` and the Bundle ID in `KeychainClearCrul.plist` to the target app.
