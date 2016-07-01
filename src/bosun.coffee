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
      res.reply "Retrieving Bosun incidents ..."
      req = request.get("#{config.host}/api/incidents/open", {timeout: config.timeout}, (err, response, body) ->
        console.log(err.code == 'ETIMEDOUT') if err
        console.log(err.connect == true) if err
        incidents = JSON.parse body
        res.reply "There are currently #{incidents.length} active incidents"
        console.log "There are currently #{incidents.length} active incidents"
        reply_message = ""
        for i in incidents
          lastAbnormalTime = new Date i.LastAbnormalTime * 1000
          start = new Date i.Start * 1000
          reply_message += "  * *#{i.Id}*: #{i.AlertName} is #{i.CurrentStatus} since #{lastAbnormalTime} and was fired at #{start} with worst status #{i.WorstStatus}.\n"
        reply_message += ""
        msgData = {
          channel: res.message.room
          text: "There are currently #{incidents.length} active incidents"
          attachments: [
            {
              fallback: "Fallback Message",
              title: "Open Incidents",
              title_link: config.host,
              text: reply_message,
              mrkdwn_in: ["text"]
            }
          ]
        }
        robot.adapter.customMessage msgData
      )
      # TODO: Wait for callback
      res.reply "Done"

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

