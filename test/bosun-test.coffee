Helper = require('hubot-test-helper')
chai = require 'chai'
auth = require 'hubot-auth'

Promise = require('bluebird')
co = require('co')
expect = chai.expect

helper = new Helper('../src/bosun.coffee')

http = require 'http'

process.env.EXPRESS_PORT = 18080

wait_time = 100

describe 'bosun', ->
  beforeEach ->
    process.env.HUBOT_BOSUN_HOST = "http://localhost:18070"
    process.env.HUBOT_BOSUN_ROLE = "bosun"
    process.env.HUBOT_BOSUN_SLACK = "no"
    process.env.HUBOT_BOSUN_LOG_LEVEL = "error"

    @room = helper.createRoom()
    @room.robot.auth = new MockAuth

    @bosun = mock_bosun()
    @bosun.listen(18070, "127.0.0.1")


  afterEach ->
    @room.destroy()
    @bosun.close()

  context "show incidents", ->

    context "show incidents for authorized user", ->
      beforeEach ->
        co =>
          yield @room.user.say 'alice', '@hubot show open bosun incidents'
          yield new Promise.delay(wait_time)

      it 'show bosun incidents', ->
        expect(@room.messages).to.eql [
          ['alice', '@hubot show open bosun incidents']
          ['hubot', '@alice Retrieving Bosun incidents ...']
          ['hubot', '@alice Yippie. Done.']
          ['hubot', '@alice So, there are currently 2 open incidents in Bosun.']
          ['hubot', '@alice 750 is warning: warning: <no value>.']
          ['hubot', '@alice 759 is normal: warning: <no value>.']
        ]

     context "Fail if unauthorized", ->

      it 'show open bosun incidents for unauthorized bob', ->
        @room.user.say('bob', '@hubot show open bosun incidents').then =>
          expect(@room.messages).to.eql [
            ['bob', '@hubot show open bosun incidents']
            ['hubot', "@bob Sorry, you're not allowed to do that. You need the 'bosun' role."]
          ]

  context "ack and close incidents", ->

    context "ack single incident", ->
      beforeEach ->
        co =>
          yield @room.user.say 'alice', '@hubot ack bosun incident 123 because it is normal again.'
          yield new Promise.delay(wait_time)

      it 'ack bosun alarm', ->
        expect(@room.messages).to.eql [
          ['alice', '@hubot ack bosun incident 123 because it is normal again.']
          ['hubot', '@alice Trying to ack Bosun incident 123 ...']
        ]

    context "ack multiple incidents", ->
      beforeEach ->
        co =>
          yield @room.user.say 'alice', '@hubot ack bosun incidents 123,234 because State is normal again.'
          yield new Promise.delay(wait_time)

      it 'ack bosun alarm', ->
        expect(@room.messages).to.eql [
          ['alice', '@hubot ack bosun incidents 123,234 because State is normal again.']
          ['hubot', '@alice Trying to ack Bosun incidents 123,234 ...']
        ]

     context "Other ack and close alarms", ->

      it 'fail to close active bosun alarm'

     context "Fail if unauthorized", ->
      it 'ack bosun incident for unauthorized bob', ->
        @room.user.say('bob', '@hubot ack bosun incident 123 because it is over.').then =>
          expect(@room.messages).to.eql [
            ['bob', '@hubot ack bosun incident 123 because it is over.']
            ['hubot', "@bob Sorry, you're not allowed to do that. You need the 'bosun' role."]
          ]

  context "error handling", ->

      it 'Catch errors'

  context "show config", ->

      it 'show bosun config'


class MockAuth
  hasRole: (user, role) ->
    if user.name is 'alice' and role is 'bosun' then true else false

mock_bosun = () ->
  http.createServer((req, resp) ->
      if req.url == '/api/incidents/open' and req.method == 'GET'
        resp.setHeader('Content-Type', 'application/json')
        incidents = [
          {
            Id: 759,
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
            NeedAck: false,
            Silenced: false,
            Actions: [
              {
                User: "lukas",
                Message: "Okay.",
                Time: 1467411397,
                Type: "Acknowledged"
              }
            ]
            Events: [ [Object], [Object] ],
            WarnNotificationChains: [],
            CritNotificationChains: []
          }
          {
            Id: 750,
            Subject: 'warning: <no value>',
            Start: 1467363958,
            AlertName: 'test.lukas',
            Tags: null,
            TagsString: '{}',
            CurrentStatus: 'warning',
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
          }
        ]
        resp.end JSON.stringify incidents

      if req.url == '/api/action' and req.method == 'POST'
        resp.end
    )


