Helper = require('hubot-test-helper')
chai = require 'chai'
auth = require 'hubot-auth'

Promise = require('bluebird')
co = require('co')
expect = chai.expect

helper = new Helper('../src/bosun.coffee')

http = require 'http'

process.env.EXPRESS_PORT = 18080

describe 'bosun', ->
  beforeEach ->
    process.env.HUBOT_BOSUN_HOST = "http://localhost:18070"
    process.env.HUBOT_BOSUN_ROLE = "bosun"
    process.env.HUBOT_BOSUN_SLACK = "no"

    @room = helper.createRoom()
    @room.robot.auth = new MockAuth

    @bosun = mock_bosun()
    @bosun.listen(18070, "127.0.0.1")


  afterEach ->
    @room.destroy()
    @bosun.close()

  context "list incidents", ->
    beforeEach ->
      co =>
        yield @room.user.say 'alice', '@hubot list open bosun incidents'
        yield new Promise.delay(1000)

    it 'list bosun incidents', ->
      expect(@room.messages).to.eql [
        ['alice', '@hubot list open bosun incidents']
        ['hubot', '@alice Retrieving Bosun incidents ...']
        ['hubot', '@alice Done.']
        ['hubot', '@alice 2 is normal: warning: <no value>.']
      ]

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
          ['hubot', "@bob Sorry, you're not allowed to do that. You need the 'bosun' role."]
        ]

  context "error handling", ->


class MockAuth
  hasRole: (user, role) ->
    if user.name is 'alice' and role is 'bosun' then true else false

mock_bosun = () ->
  http.createServer((req, resp) ->
      if req.url == '/api/incidents/open' and req.method == 'GET'
        resp.setHeader('Content-Type', 'application/json')
        incidents = [ {
          Id: 2,
          Subject: 'warning: <no value>',
          Start: 1467363958,
          AlertName: 'test.lukas',
          Tags: null,
          TagsString: '{}',
          CurrentStatus: 'normal',
          WorstStatus: 'warning',
          LastAbnormalStatus: 'warning',
          LastAbnormalTime: 1467367498,
          Unevaluated: false,
          NeedAck: true,
          Silenced: false,
          Actions: [],
          Events: [ [Object], [Object] ],
          WarnNotificationChains: [],
          CritNotificationChains: []
        } ]
        resp.end JSON.stringify incidents
    )


