# Description
#   Allows hubot to interact with Bosun.
#
# Configuration:
#   HUBOT_BOSUN_HOST - Bosun host, e.g., http://localhost:8070
#   HUBOT_BOSUN_ROLE - Hubot auth role, default is 'bosun'
#   HUBOT_BOSUN_SLACK - If 'yes' enables rich text formatting for Slack, default 'no'
#   HUBOT_BOSUN_LOG_LEVEL - Log level, default 'info'
#   HUBOT_BOSUN_TIMEOUT - Timeout for calls to Bosun host, defauult is 10.000 ms
#
# Commands:
#   show open bosun incidents - list all open incidents, unacked and acked, sorted by incident id
#   <ack|close> bosun incident[s] <Id,...> because <message> - acks or closes bosun incidents with the specific incident ids
#
# Notes:
#   Enjoy and thank Stack Exchange for Bosun -- http://bosun.org.
#
# Author:
#   lukas.pustina@gmail.com
#
# Todos:
#   * Tests
#     * Enhance Bosun mock to actually understand the ack|close commands
#   * Prod Installation
#     * Docker Container similar to Bosun for bosun_all-in-one
#     * Ansible Role similar to bosun_all-in-one
#   * Silences
#     * get
#     * set
#     * clear
#   (*) Listen for events
#     * bosun:silence x - starts silence for x min
#   (*) Graph queries

request = require 'request'
Log = require 'log'

config =
  host: process.env.HUBOT_BOSUN_HOST
  role: process.env.HUBOT_BOSUN_ROLE or "bosun"
  slack: process.env.HUBOT_BOSUN_SLACK is "yes"
  log_level: process.env.HUBOT_BOSUN_LOG_LEVEL or "info"
  timeout: if process.env.HUBOT_BOSUN_TIMEOUT then parseInt process.env.HUBOT_BOSUN_TIMEOUT else 10000

logger = new Log config.log_level

logger.notice "hubot-bosun: Started with Bosun server #{config.host}, Slack #{if config.slack then 'en' else 'dis'}abled, timeout set to #{config.timeout}, and log level #{config.log_level}."

module.exports = (robot) ->

  robot.respond /show open bosun incidents/i, (res) ->
    if is_authorized robot, res
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
              # TODO: Find better format for date
              start = new Date(i.Start * 1000).toISOString().replace(/T/, ' ').replace(/\..+/, ' UTC')
              color = switch i.CurrentStatus
                when 'normal' then 'good'
                when 'warning' then 'warning'
                when 'critical' then 'danger'
                else '#439FE0'
              acked = if i.NeedAck then '*Unacked*' else 'Acked'

              actions = for a in i.Actions
                time = new Date(a.Time * 1000).toISOString().replace(/T/, ' ').replace(/\..+/, ' UTC')
                "* #{a.User} #{a.Type.toLowerCase()} this incident at #{time}."
              text = "#{acked} and active since #{start} with _#{i.TagsString}_."
              text += '\n' if actions.length > 0
              text += actions.join('\n')

              attachments.push {
                fallback: "Incident #{i.Id} is #{i.CurrentStatus}"
                color: color
                title: "#{i.Id}: #{i.Subject}"
                title_link: "#{config.host}/incident?id=#{i.Id}"
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
    if is_authorized robot, res
      user_name = res.envelope.user.name
      action = res.match[1]
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

          unless config.slack and response.statusCode is not 200
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


  robot.error (err, res) ->
    robot.logger.error "hubot-bosun: DOES NOT COMPUTE"

    if res?
      res.reply "DOES NOT COMPUTE: #{err}"


is_authorized = (robot, res) ->
  user = res.envelope.user
  unless robot.auth.hasRole(user, config.role)
    warn_unauthorized res
    false
  else
    true

warn_unauthorized = (res) ->
  user = res.envelope.user.name
  message = res.message.text
  logger.warning "hubot-bosun: #{user} tried to run '#{message}' but was not authorized."
  res.reply "Sorry, you're not allowed to do that. You need the '#{config.role}' role."

handle_bosun_err = (res, err, response, body) ->
  logger.error "hubot-bosun: Requst to Bosun timed out." if err.code is 'ETIMEDOUT'
  logger.error "hubot-bosun: Connection to Bosun failed." if err.connect is true or err.code is 'ECONNREFUSED'
  logger.error "hubot-bosun: Failed to retrieve response from Bosun. Error: '#{err}', reponse: '#{response}', body: '#{body}'"
  res.reply "Ouuch. I'm sorry, but I couldn't contact Bosun."


