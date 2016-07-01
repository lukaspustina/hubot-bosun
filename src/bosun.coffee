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

config =
  host: process.env.HUBOT_BOSUN_HOST
  role: process.env.HUBOT_BOSUN_ROLE
  timeout: 10000

module.exports = (robot) ->

  robot.respond /list open bosun incidents/i, (res) ->
    if is_authorized robot, res
      console.log "Retrieving Bosun incidents requested by #{res.envelope.user.name}."
      res.reply "Retrieving Bosun incidents ..."
      req = request.get("#{config.host}/api/incidents/open", {timeout: config.timeout}, (err, response, body) ->
        console.log(err.code == 'ETIMEDOUT') if err
        console.log(err.connect == true) if err
        res.reply "Done."
        incidents = JSON.parse body
        console.log "There are currently #{incidents.length} active incidents in Bosun."
        attachments = []
        for i in incidents
          # TODO: Format date resonable
          start = new Date(i.Start * 1000).toISOString().replace(/T/, ' ').replace(/\..+/, ' UTC')
          color = switch i.CurrentStatus
            when 'normal' then 'good'
            when 'warning' then 'warning'
            when 'critical' then 'danger'
            else '#439FE0'
          acked = if i.NeedAck then '*Unacked*' else 'Acked'
          attachment = {
            fallback: "Incident #{i.Id} is #{i.CurrentStatus}"
            color: color
            title: "#{i.Id}: #{i.Subject}"
            title_link: "#{config.host}/incident?id=#{i.Id}"
            text: "#{acked} and active since #{start} with #{i.TagsString}."
            mrkdwn_in: ["text"]
          }
          attachments.push attachment

        msgData = {
          channel: res.message.room
          text: "There are currently #{incidents.length} active incidents in Bosun."
          attachments: attachments
        }
        robot.adapter.customMessage msgData
      )
      # TODO: Wait for callback

  robot.respond /(ack|close) bosun incident #(\d+)/i, (res) ->
    if is_authorized robot, res
      action = res.match[1]
      incident = res.match[2]
      res.reply "Will #{action} bosun incident ##{incident}."

  robot.hear /orly/, (res) ->
    res.send "yarly"

  robot.error (err, res) ->
    robot.logger.error "DOES NOT COMPUTE"

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
  user = res.envelope.user
  message = res.message.text
  console.log "#{user} tried to run '#{message}' but was not authorized."
  res.reply "Sorry, you're not allowed to do that. You need the '#{config.role}' role."

