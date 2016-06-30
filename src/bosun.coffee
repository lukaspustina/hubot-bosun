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

module.exports = (robot) ->
  robot.respond /(ack|close) bosun incident #(\d+)/i, (res) ->
    action = res.match[1]
    incident = res.match[2]
    if robot.auth.hasRole res.message.user.name, 'bosun'
      res.reply "Will #{action} bosun incident ##{incident}."
    else
      unauthorized res

  robot.hear /orly/, (res) ->
    res.send "yarly"

  robot.error (err, res) ->
    robot.logger.error "DOES NOT COMPUTE"

    if res?
      res.reply "DOES NOT COMPUTE: #{err}"


unauthorized = (res) ->
  user = res.message.user.name
  message = res.message.text
  res.reply "Sorry, you're not allowed to do that."

