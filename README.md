# hubot-bosun

[![Build Status](https://travis-ci.org/lukaspustina/hubot-bosun.svg?branch=master)](https://travis-ci.org/lukaspustina/hubot-bosun)

[![NPM](https://nodei.co/npm/hubot-bosun.png)](https://nodei.co/npm/hubot-bosun/)

Allows [Hubot](https://hubot.github.com) to interact with [Bosun](http://bosun.org).

See [`src/bosun.coffee`](src/bosun.coffee) for full documentation.

## Installation

In the hubot project repo, run:

`npm install hubot-bosun --save`

Then add **hubot-bosun** to your `external-scripts.json`:

```json
[
  "hubot-bosun"
]
```

## Configuration

**hubot-bosun** may be used with [hubot-auth](https://github.com/hubot-scripts/hubot-auth) and can be configured via the following environment variables:

* `HUBOT_BOSUN_HOST` -- Bosun server URL, e.g., `http://localhost:8070`
* `HUBOT_BOSUN_LINK_URL` -- If set, this URL will be used for links instead of `HUBOT_BOSUN_HOST`
* `HUBOT_BOSUN_ROLE` -- If set, auth role required to interact with Bosun. Default is `bosun`
* `HUBOT_BOSUN_SLACK` -- If `yes` enables rich text formatting for Slack, default is `no`
* `HUBOT_BOSUN_LOG_LEVEL` -- Log level, default is `info`
* `HUBOT_BOSUN_TIMEOUT` --  Timeout for Bosun API calls in milliseconds; default is `10000`
* `HUBOT_BOSUN_RELATIVE_TIME` -- If `yes` all dates and times are presented relative to now, e.g. _2 min ago_

## Commands

### Incidents

* `show open bosun incidents` shows all open incidents, unacked and acked, sorted by incident id
* `<ack|close> bosun incident[s] <Id,...> because <message>` acks or closes bosun incidents with the specified incident ids

### Silences

* `show bosun silences` shows all active silences
* `<set|test> bosun silence for <alert|tagkey>=value[,...] for <duration> because <message>` sets or tests a new silence, e.g., `set bosun silence for alert=test.lukas,host=muffin for 1h because I want to`. Can also be used with alert or tags only.
* `clear bosun silence <id>` deletes silence with the specific silence id

## Events

Please see the event handlers in `src/bosun.coffee` for the specific event formats.

### Accepts the following events

* `bosun.set_silence`
* `bosun.clear_silence`
* `bosun.check_silence`

###  Emits the following events
*  `bosun.result.set_silence.successful`
*  `bosun.result.set_silence.failed`
*  `bosun.result.clear_silence.successful`
*  `bosun.result.clear_silence.failed`
*  `bosun.result.check_silence.successful`
*  `bosun.result.check_silence.failed`

## Sample Interaction

### Plain

```
Lukas Pustina> list open bosun incidents

hubot> @lukas.pustina: Retrieving Bosun incidents ...

hubot> @lukas.pustina: Yippie. Done.
 So, there are currently 2 open incidents in Bosun.
 4: critical: <no value> on muffin
 Acked and active since 2 hours with {host=muffin}.
 lukas.pustina acknowledged this incident at a few seconds ago.
 5: warning: <no value> on cake
 Acked and active since 3 hours with {host=cake}.
 lukas.pustina acknowledged this incident at a few seconds ago.

Lukas Pustina> close bosun incidents 4,5 because Everything is fine again.

hubot> @lukas.pustina: Trying to close Bosun incidents 4,5 ...

hubut> @lukas.pustina: Yippie. Done.

Lukas Pustina> list open bosun incidents

hubot> @lukas.pustina: Retrieving Bosun incidents ...

hubot> @lukas.pustina: Yippie. Done.
 Oh, no incidents there. Everything is ok.
```

### Slack

![Slack interaction](docs/slack.png)

## NPM Module

https://www.npmjs.com/package/hubot-bosun
