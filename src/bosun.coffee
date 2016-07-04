# Description
#   Allows hubot to interact with Bosun.
#
# Configuration:
#   LIST_OF_ENV_VARS_TO_SET
#
# Commands:
#   hubot hello - <what the respond trigger does>
#   orly - <what the hear trigger does>
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   lukas.pustina@gmail.com

request = require 'request'
Log = require 'log'

config =
  host: process.env.HUBOT_BOSUN_HOST
  role: process.env.HUBOT_BOSUN_ROLE
  slack: if process.env.HUBOT_BOSUN_SLACK is "yes" then true else false
  log_level: process.env.HUBOT_BOSUN_LOG_LEVEL or "info"
  timeout: 10000

logger = new Log config.log_level

logger.notice "hubot-bosun: Started with Slack #{if config.slack then 'en' else 'dis'}abled and log level #{config.log_level}."

module.exports = (robot) ->

  robot.respond /list open bosun incidents/i, (res) ->
    if is_authorized robot, res
      logger.info "hubot-bosun: Retrieving Bosun incidents requested by #{res.envelope.user.name}."
      res.reply "Retrieving Bosun incidents ..."
      req = request.get("#{config.host}/api/incidents/open", {timeout: config.timeout}, (err, response, body) ->
        if err
          logger.error "hubot-bosun: Requst to Bosun timed out." if err and (err.code == 'ETIMEDOUT')
          logger.error "hubot-bosun: Connection to Bosun failed." if err and (err.connect == true)
          res.reply "Ouuch. I'm sorry, but I could not contact Bosun."
        else
          res.reply "Yippie. Done."

        incidents = JSON.parse body
        incidents.sort( (a,b) -> parseInt(a.Id) > parseInt(b.Id) )
        status = "So, there are currently #{incidents.length} active incidents in Bosun."
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

            attachments.push {
              fallback: "Incident #{i.Id} is #{i.CurrentStatus}"
              color: color
              title: "#{i.Id}: #{i.Subject}"
              title_link: "#{config.host}/incident?id=#{i.Id}"
              text: "#{acked} and active since #{start} with #{i.TagsString}."
              mrkdwn_in: ["text"]
            }

          robot.adapter.customMessage {
            channel: res.message.room
            text: status
            attachments: attachments
          }
      )

  robot.respond /(ack|close) bosun incident #(\d+)/i, (res) ->
    if is_authorized robot, res
      action = res.match[1]
      incident = res.match[2]
      res.reply "Will #{action} bosun incident ##{incident}."

  robot.hear /orly/, (res) ->
    res.send "yarly"

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

