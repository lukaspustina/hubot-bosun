Helper = require('hubot-test-helper')
chai = require 'chai'
auth = require 'hubot-auth'

expect = chai.expect

helper = new Helper('../src/bosun.coffee')

class MockAuth
  hasRole: (user, role) ->
    if user is 'alice' and role is 'bosun' then true else false

describe 'bosun', ->
  beforeEach ->
    @room = helper.createRoom()
    @room.robot.auth = new MockAuth

  afterEach ->
    @room.destroy()

  context "ack and close alarms", ->

    it 'ack bosun alarm', ->
      @room.user.say('alice', '@hubot ack bosun incident #123').then =>
        expect(@room.messages).to.eql [
          ['alice', '@hubot ack bosun incident #123']
          ['hubot', '@alice Will ack bosun incident #123.']
        ]

    it 'close bosun alarm', ->
      @room.user.say('alice', '@hubot ack bosun incident #123').then =>
        expect(@room.messages).to.eql [
          ['alice', '@hubot ack bosun incident #123']
          ['hubot', '@alice Will ack bosun incident #123.']
        ]

    it 'ack bosun alarm for unauthorized bob', ->
      @room.user.say('bob', '@hubot ack bosun incident #123').then =>
        expect(@room.messages).to.eql [
          ['bob', '@hubot ack bosun incident #123']
          ['hubot', "@bob Sorry, you're not allowed to do that."]
        ]

  context "error handling", ->

