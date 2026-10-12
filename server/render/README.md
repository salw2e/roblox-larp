# render

draws avatars ourselves so the 6 an hour limit on roblox's own renderer stops mattering. its [roavatar-renderer](https://github.com/steinann/RoAvatar-Renderer) running in a headless chrome, the avatar service asks it over http and turns the result into the obj the app loads

```
npm install
npm run build
ROBLOX_COOKIE_FILE=cookie.txt npm start
```

then start the avatar service with `BLOX_RENDER=http://127.0.0.1:8096`. without it everything still works, just through roblox with the limit

needs chrome somewhere (`CHROME=/path/to/chrome`, default `/opt/google/chrome/chrome`)

this folder is GPL-3.0 because roavatar-renderer is, the rest of the repo stays MIT
