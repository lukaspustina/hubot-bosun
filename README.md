# hubot-bosun

Allows hubot to interact with Bosun.

See [`src/bosun.coffee`](src/bosun.coffee) for full documentation.

## Installation

In hubot project repo, run:

`npm install hubot-bosun --save`

Then add **hubot-bosun** to your `external-scripts.json`:

```json
[
  "hubot-bosun"
]
```

## Sample Interaction

```
Lukas Pustina> list open bosun incidents

hubot> @lukas.pustina: Retrieving Bosun incidents ...

hubot> @lukas.pustina: Yippie. Done.
 So, there are currently 2 open incidents in Bosun.
 4: critical: <no value> on muffin
 Acked and active since 2016-07-04 13:28:28 UTC with {host=muffin}.
 lukas.pustina acknowledged this incident at 2016-07-04 13:29:37 UTC.
 5: warning: <no value> on cake
 Acked and active since 2016-07-04 13:28:28 UTC with {host=cake}.
 lukas.pustina acknowledged this incident at 2016-07-04 13:29:38 UTC.

Lukas Pustina> close bosun incidents #4,5 because All is fine again.

hubot> @lukas.pustina: Trying to close Bosun incidents #4,5 ...

hubut> @lukas.pustina: Yippie. Done.

Lukas Pustina> list open bosun incidents

hubot> @lukas.pustina: Retrieving Bosun incidents ...

hubot> @lukas.pustina: Yippie. Done.
 Oh, no incidents there. Everything is ok.
```

## NPM Module

https://www.npmjs.com/package/hubot-bosun
