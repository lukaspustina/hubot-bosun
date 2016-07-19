# Description
#   Allows hubot to interact with Bosun.
#
# Configuration:
#   HUBOT_BOSUN_HOST -- Bosun server URL, e.g., `http://localhost:8070`
#   HUBOT_BOSUN_LINK_URL -- If set, this URL will be used for links instead of `HUBOT_BOSUN_HOST`
#   HUBOT_BOSUN_ROLE -- If set, auth role required to interact with Bosun. Default is `bosun`
#   HUBOT_BOSUN_SLACK -- If `yes` enables rich text formatting for Slack, default is `no`
#   HUBOT_BOSUN_LOG_LEVEL -- Log level, default is `info`
#   HUBOT_BOSUN_TIMEOUT --  Timeout for Bosun API calls in milliseconds; default is `10000`
#   HUBOT_BOSUN_RELATIVE_TIME -- If `yes` all dates and times are presented relative to now, e.g. _2 min ago_
#
# Commands:
#   show open bosun incidents -- shows all open incidents, unacked and acked, sorted by incident id
#   <ack|close> bosun incident[s] <Id,...> because <message> -- acks or closes bosun incidents with the specific incident ids
#   show bosun silences -- shows all active silences
#   <set|test> bosun silence for <alert|tagkey>=value[,...] for <duration> because <message> -- sets or tests a new silence, e.g., `set bosun silence for alert=test.lukas,host=muffin for 1h because I want to`. Can also be used with alert or tags only.
#   clear bosun silence <id> -- deletes silence with the specific silence id
#
# Events:
#   Accepts the following events:
#     bosun.set_silence
#     bosun.clear_silence
#     bosun.check_silence
#   Emits the following events:
#     bosun.result.set_silence.successful
#     bosun.result.set_silence.failed
#     bosun.result.clear_silence.successful
#     bosun.result.clear_silence.failed
#     bosun.result.check_silence.successful
#     bosun.result.check_silence.failed
#   Please see the event handlers for the specific event formats.
#
# Notes:
#   Enjoy and thank Stack Exchange for Bosun -- http://bosun.org.
#
# Author:
#   lukas.pustina@gmail.com
#
# Todos:
#   (*) Graph queries

request = require 'request'
Log = require 'log'
moment = require 'moment'

config =
  host: process.env.HUBOT_BOSUN_HOST
  link_url: process.env.HUBOT_BOSUN_LINK_URL or process.env.HUBOT_BOSUN_HOST
  role: process.env.HUBOT_BOSUN_ROLE or ""
  slack: process.env.HUBOT_BOSUN_SLACK is "yes"
  log_level: process.env.HUBOT_BOSUN_LOG_LEVEL or "info"
  timeout: if process.env.HUBOT_BOSUN_TIMEOUT then parseInt process.env.HUBOT_BOSUN_TIMEOUT else 10000
  relative_time: process.env.HUBOT_BOSUN_RELATIVE_TIME is "yes"

logger = new Log config.log_level

logger.notice "hubot-bosun: Started with Bosun server #{config.host}, link URL #{config.link_url}, Slack #{if config.slack then 'en' else 'dis'}abled, timeout set to #{config.timeout}, and log level #{config.log_level}."

module.exports = (robot) ->

  robot.respond /show open bosun incidents/i, (res) ->
    unless is_authorized robot, res.envelope.user
      warn_unauthorized res
    else
      user_name = res.envelope.user.name
      logger.info "hubot-bosun: Retrieving Bosun incidents requested by #{user_name}."

      res.reply "Retrieving Bosun incidents ..."

      req = request.get("#{config.host}/api/incidents/open", {timeout: config.timeout}, (err, response, body) ->
        if err
          handle_bosun_err res, err, response, body
        else
          res.reply "Yippie. Done."

          incidents = JSON.parse body
          incidents.sort( (a,b) -> parseInt(a.Id) > parseInt(b.Id) )

          status =
            if incidents.length is 0
            then "Oh, no incidents there. Everything is ok."
            else "So, there are currently #{incidents.length} open incidents in Bosun."
          logger.info "hubot-bosun: #{status}"

          unless config.slack
            res.reply status
            for i in incidents
              res.reply "#{i.Id} is #{i.CurrentStatus}: #{i.Subject}."
          else
            attachments = []
            for i in incidents
              start = format_date_str(new Date(i.Start * 1000).toISOString())
              color = switch i.CurrentStatus
                when 'normal' then 'good'
                when 'warning' then 'warning'
                when 'critical' then 'danger'
                else '#439FE0'
              acked = if i.NeedAck then '*Unacked*' else 'Acked'

              actions = for a in i.Actions
                time = format_date_str(new Date(a.Time * 1000).toISOString())
                "* #{a.User} #{a.Type.toLowerCase()} this incident at #{time}."
              text = "#{acked} and active since #{start} with _#{i.TagsString}_."
              text += '\n' if actions.length > 0
              text += actions.join('\n')

              attachments.push {
                fallback: "Incident #{i.Id} is #{i.CurrentStatus}"
                color: color
                title: "#{i.Id}: #{i.Subject}"
                title_link: "#{config.link_url}/incident?id=#{i.Id}"
                text: text
                mrkdwn_in: ["text"]
              }

            robot.adapter.customMessage {
              channel: res.message.room
              text: status
              attachments: attachments
            }
      )

  robot.respond /(ack|close) bosun incident[s]* ([\d,]+) because (.+)/i, (res) ->
    unless is_authorized robot, res.envelope.user
      warn_unauthorized res
    else
      user_name = res.envelope.user.name
      action = res.match[1].toLowerCase()
      ids = (parseInt(incident) for incident in res.match[2].split ',')
      message = res.match[3]
      logger.info "hubot-bosun: Executing '#{action}' for incident(s) #{ids.join(',')} requested by #{user_name}."

      res.reply "Trying to #{action} Bosun incident#{if ids.length > 1 then 's' else ''} #{ids.join(',')} ..."

      data = {
        Type: "#{action}"
        User: "#{user_name}"
        Message: "#{message}"
        Ids: ids
        Notify: true
      }
      req = request.post("#{config.host}/api/action", {timeout: config.timeout, json: true, body: data}, (err, response, body) ->
        if err
          handle_bosun_err res, err, response, body
        else
          logger.info "hubot-buson: Bosun replied with HTTP status code #{response.statusCode}"

          answer = switch response.statusCode
            when 200 then "Yippie. Done."
            when 500 then "Bosun couldn't deal with that; maybe the incident doesn't exists or is still active? I suggest, you list the now open incidents. That's what Bosun told me: ```\n#{body}\n```"
            else "Puh, no sure what happened. I asked Bosun politely, but I got a weird answer. Bosun said '#{body}'."

          if not config.slack or response.statusCode is 200
            res.reply answer
          else
            robot.adapter.customMessage {
              channel: res.message.room
              attachments: [ {
                fallback: "#{answer}"
                color: 'danger'
                title: "Argh. Failed to deal with Bosun's answer."
                text: answer
                mrkdwn_in: ["text"]
              } ]
            }
      )

  robot.respond /show bosun silence[s]*/i, (res) ->
    unless is_authorized robot, res.envelope.user
      warn_unauthorized res
    else
      user_name = res.envelope.user.name
      logger.info "hubot-bosun: Retrieving Bosun silences requested by #{user_name}."

      res.reply "Retrieving Bosun silences ..."

      req = request.get("#{config.host}/api/silence/get", {timeout: config.timeout}, (err, response, body) ->
        if err
          handle_bosun_err res, err, response, body
        else
          res.reply "Yippie. Done."

          silences = JSON.parse body

          status =
            if silences.length is 0
            then "Oh, no silences there. Everybody is on watch."
            else "So, there are currently #{Object.keys(silences).length} active silences in Bosun."
          logger.info "hubot-bosun: #{status}"

          console.log

          unless config.slack
            res.reply status
            for k in Object.keys silences
              s = silences[k]
              start = format_date_str s.Start
              end = format_date_str s.End
              res.reply "Silence #{k} from #{start} until #{end} for tags #{s.TagString} and alert '#{s.Alert}' because #{s.Message}"
          else
            attachments = []
            for id in Object.keys silences
              s = silences[id]
              start = format_date_str s.Start
              end = format_date_str s.End

              is_active = moment(s.End).isBefore moment()

              color = switch is_active
                when true then 'danger'
                when false then 'good'
                when true then 'danger'

              text = "Active from #{start} until #{end}"
              text += "\nMessage: _#{s.Message}_"
              text += "\nAlert: #{s.Alert}" if s.Alert != ""
              text += "\nTags: #{s.TagString}" if s.TagsString != ""
              text += "\nId: #{id}"

              attachments.push {
                fallback: "Slience #{id} is #{if is_active then "active" else "inactive"}."
                color: color
                title: "Slience is #{if is_active then "active" else "inactive"}."
                title_link: "#{config.link_url}/silence"
                text: text
                mrkdwn_in: ["text"]
              }

            robot.adapter.customMessage {
              channel: res.message.room
              text: status
              attachments: attachments
            }
      )




  robot.respond /(set|test) bosun silence for (.+) for (.+) because (.+)/i, (res) ->
    unless is_authorized robot, res.envelope.user
      warn_unauthorized res
    else
      user_name = res.envelope.user.name
      action = res.match[1].toLowerCase()
      alert_tags_str = res.match[2]
      alert_tags = (
        dict = {}
        for alert_tag in alert_tags_str.split ','
          [k, v] = alert_tag.split '='
          dict[k] = v
        dict
      )
      duration = res.match[3]
      message = res.match[4]
      logger.info "hubot-bosun: #{action}ing silence for #{alert_tags_str} for #{duration} requested by #{user_name}."

      alert = if alert_tags.alert? then alert_tags.alert else ""
      delete alert_tags.alert if alert_tags.alert?
      tags = alert_tags

      answer = switch action
        when 'test' then "Trying to test Bosun silence"
        when 'set' then "Trying to set Bosun silence"
      answer += " for alert '#{alert}'" if alert != ""
      answer += if alert !="" and Object.keys(tags).length > 0 then " and" else " for"
      tags_str = JSON.stringify(tags).replace(/\"/g,'')
      answer += " tags #{tags_str} for" if Object.keys(tags).length > 0
      answer += " #{duration}"

      res.reply "#{answer} ..."

      tag_str = ("#{k}=#{tags[k]}" for k in Object.keys(tags)).join(',')
      data = {
        duration: "#{duration}"
        alert: "#{alert}"
        tags: tag_str
        user: "#{user_name}"
        message: "#{message}"
        forget: "true"
      }
      data.confirm = "true" if action == 'set'

      req = request.post("#{config.host}/api/silence/set", {timeout: config.timeout, json: true, body: data}, (err, response, body) ->
        if err
          handle_bosun_err res, err, response, body
        else
          logger.info "hubot-buson: Bosun replied with HTTP status code #{response.statusCode}"

          answer = switch response.statusCode
            when 200
              if action == 'set' then "Yippie. Done. Admire your alarm at #{config.host}/silence."
              else "Yippie. Done. That alarm will work."
            when 500 then "Bosun couldn't deal with that. I suggest, you list the active silences now. That's what Bosun told me: ```\n#{body}\n```"
            else "Puh, no sure what happened. I asked Bosun politely, but I got a weird answer. Bosun said '#{body}'."

          if not config.slack or response.statusCode is 200
            res.reply answer
          else
            robot.adapter.customMessage {
              channel: res.message.room
              attachments: [ {
                fallback: "#{answer}"
                color: 'danger'
                title: "Argh. Failed to deal with Bosun's answer."
                text: answer
                mrkdwn_in: ["text"]
              } ]
            }
      )


  robot.respond /clear bosun silence (.+)/i, (res) ->
    unless is_authorized robot, res.envelope.user
      warn_unauthorized res
    else
      user_name = res.envelope.user.name
      id = res.match[1]
      logger.info "hubot-bosun: Clearing silence '#{id}' requested by #{user_name}."

      res.reply "Trying to clear Bosun silence #{id} ..."

      req = request.post("#{config.host}/api/silence/clear?id=#{id}", {timeout: config.timeout, json: true, body: {}}, (err, response, body) ->
        if err
          handle_bosun_err res, err, response, body
        else
          logger.info "hubot-buson: Bosun replied with HTTP status code #{response.statusCode}"

          answer = switch response.statusCode
            when 200 then "Yippie. Done."
            when 500 then "Bosun couldn't deal with that; maybe the silence doesn't exists? I suggest, you list the open silences now. That's what Bosun told me: ```\n#{body}\n```"
            else "Puh, no sure what happened. I asked Bosun politely, but I got a weird answer. Bosun said '#{body}'."


          if not config.slack or response.statusCode is 200
            res.reply answer
          else
            robot.adapter.customMessage {
              channel: res.message.room
              attachments: [ {
                fallback: "#{answer}"
                color: 'danger'
                title: "Argh. Failed to deal with Bosun's answer."
                text: answer
                mrkdwn_in: ["text"]
              } ]
            }
      )

  robot.on 'bosun.set_silence', (event) ->
    unless is_authorized robot, event.user
      logger.warning "hubot-bosun: #{event.user} tried to run event 'bosun.set_silence' but was not authorized."
    else
      logger.info "hubot-bosun: setting silence for alert '#{event.alert}' and tags '#{event.tags}' for #{event.duration} requested by #{event.user.name} via event."

      data =
        duration: event.duration
        alert: event.alert
        tags: event.tags
        message: event.message
        forget: event.forget
        confirm: "true"
      req = request.post("#{config.host}/api/silence/set", {timeout: config.timeout, json: true, body: data}, (err, response, body) ->
        if err
          handle_bosun_err null, err, response, body
          robot.emit 'bosun.result.set_silence.failed', {
            user: event.user
            room: event.room
            message: "Connection to Bosun failed."
          }
        else if response and response.statusCode != 200
          robot.emit 'bosun.result.set_silence.failed', {
            user: event.user
            room: event.room
            message: "API call failed with status code #{response.statusCode}."
          }
        else
          # ARGH: Bosun does not return the ID of the Silence via API, so we have to figure it out with a second call and some heuristics
          req = request.get("#{config.host}/api/silence/get", {timeout: config.timeout}, (err, response, body) ->
            if err
              handle_bosun_err res, err, response, body
              robot.emit 'bosun.result.set_silence.failed', {
                user: event.user
                room: event.room
                message: "Cloud not retrieve actives silences after setting your's; status code #{response.statusCode}."
              }
            else
              silences = JSON.parse body
              # map silences from object to array and add unix_time_stamp for time based ordering
              silences = ({Id: k, start_as_unix_time: moment(v.Start).valueOf(), silence: v} for k,v of silences)
              silences.sort( (a,b) -> a.start_as_unix_time < b.start_as_unix_time )
              # This should be the younges alarm
              silence_id = silences[0].Id

              robot.emit 'bosun.result.set_silence.successful',
                user: event.user
                room: event.room
                duration: event.duration
                silence_id: silence_id
          )
      )

  robot.on 'bosun.clear_silence', (event) ->
    unless is_authorized robot, event.user
      logger.warning "hubot-bosun: #{event.user} tried to run event 'bosun.clear_silence' but was not authorized."
    else
      logger.info "hubot-bosun: clearing silence with id '#{event.silence_id}' equested by #{event.user.name} via event."

      req = request.post("#{config.host}/api/silence/clear?id=#{event.silence_id}", {timeout: config.timeout, json: true, body: {}}, (err, response, body) ->
        if err
          handle_bosun_err null, err, response, body
          robot.emit 'bosun.result.clear_silence.failed', {
            user: event.user
            room: event.room
            silence_id: event.silence_id
            message: "Connection to Bosun failed."
          }
        else if response and response.statusCode != 200
          robot.emit 'bosun.result.clear_silence.failed', {
            user: event.user
            room: event.room
            silence_id: event.silence_id
            message: "API call failed with status code #{response.statusCode}."
          }
        else
          robot.emit 'bosun.result.clear_silence.successful', event
      )


  robot.on 'bosun.check_silence', (event) ->
    unless is_authorized robot, event.user
      logger.warning "hubot-bosun: #{event.user} tried to run event 'bosun.check_silence' but was not authorized."
    else
      logger.info "hubot-bosun: checking silence requested by #{event.user.name} via event."

      req = request.get("#{config.host}/api/silence/get", {timeout: config.timeout}, (err, response, body) ->
        if err
          handle_bosun_err res, err, response, body
          robot.emit 'bosun.result.check_silence.failed', {
            user: event.user
            room: event.room
            message: "Cloud not retrieve actives silences; status code #{response.statusCode}."
          }
        else
          silences = JSON.parse body
          silences = (k for k,v of silences)
          active = event.silence_id in silences

          robot.emit 'bosun.result.check_silence.successful',
            user: event.user
            room: event.room
            silence_id: event.silence_id
            active: active
      )


  robot.error (err, res) ->
    robot.logger.error "hubot-bosun: DOES NOT COMPUTE"

    if res?
      res.reply "DOES NOT COMPUTE: #{err}"


is_authorized = (robot, user) ->
  logger.debug "Checking authorization for user '#{user.name}' and role '#{config.role}': role is #{config.role is ""}, auth is #{robot.auth.hasRole(user, config.role)}, combined is #{config.role is "" or robot.auth.hasRole(user, config.role)}."
  config.role is "" or robot.auth.hasRole(user, config.role)

warn_unauthorized = (res) ->
  user = res.envelope.user.name
  message = res.message.text
  logger.warning "hubot-bosun: #{user} tried to run '#{message}' but was not authorized."
  res.reply "Sorry, you're not allowed to do that. You need the '#{config.role}' role."

handle_bosun_err = (res, err, response, body) ->
  logger.error "hubot-bosun: Requst to Bosun timed out." if err? and err.code is 'ETIMEDOUT'
  logger.error "hubot-bosun: Connection to Bosun failed." if err? and err.connect is true or err.code is 'ECONNREFUSED'
  logger.error "hubot-bosun: Failed to retrieve response from Bosun. Error: '#{err}', reponse: '#{response}', body: '#{body}'"
  if res
    res.reply "Ouuch. I'm sorry, but I couldn't contact Bosun."

format_date_str = (date_str) ->
  if config.relative_time
    moment(date_str).fromNow()
  else
    date_str.replace(/T/, ' ').replace(/\..+/, ' UTC')

