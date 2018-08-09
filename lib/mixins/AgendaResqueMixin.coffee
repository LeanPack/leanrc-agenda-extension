

os            = require 'os'
Agenda        = require 'agenda'
{MongoClient} = require 'mongodb'

###
```coffee
module.exports = (Module)->
  class ApplicationResque extends Module::Resque
    @inheritProtected()
    @include Module::AgendaResqueMixin # в этом миксине должны быть реализованы платформозависимые методы, которые будут посылать нативные запросы к реальной базе данных

    @module Module

  return ApplicationResque.initialize()
```

```coffee
module.exports = (Module)->
  {RESQUE} = Module::

  class PrepareModelCommand extends Module::SimpleCommand
    @inheritProtected()

    @module Module

    @public execute: Function,
      default: ->
        #...
        @facade.registerProxy Module::ApplicationResque.new RESQUE
        #...

  PrepareModelCommand.initialize()
```
###


module.exports = (Module)->
  {
    Resque
    ConfigurableMixin
    PromiseInterface
    Utils: {_, co}
  } = Module::

  _connection = null
  _consumers = null
  _agenda = null

  Module.defineMixin 'AgendaResqueMixin', (BaseClass = Resque) ->
    class extends BaseClass
      @inheritProtected()

      @include ConfigurableMixin

      @public connection: PromiseInterface,
        get: ->
          self = @
          _connection ?= co ->
            credentials = ''
            {address, jobsCollection:collection} = self.configs.agenda
            name = "#{os.hostname()}-#{process.pid}"
            yield Module::Promise.new (resolve, reject) ->
              connection = null
              _agenda = Module::Promise.new (resolveAgenda, rejectAgenda) ->
                MongoClient.connect address
                .then (conn) ->
                  connection = conn
                  voAgenda = new Agenda()
                    .mongo connection, collection ? 'delayedJobs'
                    .name name
                    .maxConcurrency 16
                    .defaultConcurrency 16
                    .lockLimit 16
                    .defaultLockLimit 16
                    .defaultLockLifetime 5000
                  voAgenda.on 'ready', ->
                    resolveAgenda voAgenda
                  voAgenda.on 'error', (err) ->
                    rejectAgenda err
                  return
                return
              _agenda
              .then ->
                resolve connection
              .catch (err) ->
                reject err
              return
          _connection

      @public onRegister: Function,
        default: (args...)->
          @super args...
          do => @connection
          _consumers ?= 0
          _consumers++
          return

      @public @async onRemove: Function,
        default: (args...)->
          @super args...
          _consumers--
          if _consumers is 0
            connection = yield _connection
            yield connection.close(true)
            _connection = undefined
          yield return

      @public @async getAgenda: Function,
        default: ->
          return yield _agenda

      @public @async ensureQueue: Function,
        default: (name, concurrency = 1)->
          name = @fullQueueName name
          {queuesCollection} = @configs.agenda
          voQueuesCollection = (yield _agenda)._mdb.collection queuesCollection ? 'delayedQueues'
          if (queue = yield voQueuesCollection.findOne name: name)?
            queue.concurrency = concurrency
            yield voQueuesCollection.updateOne {name}, queue
          else
            yield voQueuesCollection.insertOne {name, concurrency}
          yield return {name, concurrency}

      @public @async getQueue: Function,
        default: (name)->
          name = @fullQueueName name
          {queuesCollection} = @configs.agenda
          voQueuesCollection = (yield _agenda)._mdb.collection queuesCollection ? 'delayedQueues'
          if (queue = yield voQueuesCollection.findOne name: name)?
            {concurrency} = queue
            yield return {name, concurrency}
          else
            yield return

      @public @async removeQueue: Function,
        default: (queueName)->
          queueName = @fullQueueName queueName
          {queuesCollection} = @configs.agenda
          voQueuesCollection = (yield _agenda)._mdb.collection queuesCollection ? 'delayedQueues'
          yield voQueuesCollection.deleteOne name: queueName
          yield return

      @public @async allQueues: Function,
        default: ->
          {queuesCollection} = @configs.agenda
          voQueuesCollection = (yield _agenda)._mdb.collection queuesCollection ? 'delayedQueues'
          queues = yield voQueuesCollection.find {}
          queues = yield queues.toArray()
          queues = queues.map ({ name, concurrency }) -> { name, concurrency }
          yield return queues

      @public @async pushJob: Function,
        default: (queueName, scriptName, data, delayUntil)->
          queueName = @fullQueueName queueName
          voAgenda = yield _agenda
          createJob = (name, data, { delayUntil }, cb) ->
            if delayUntil?
              voAgenda.schedule delayUntil, name, data, cb
            else
              voAgenda.now name, data, cb
          yield return Module::Promise.new (resolve, reject)->
            job = createJob queueName, {scriptName, data}, { delayUntil }, (err) ->
              if err?
                reject err
              else
                resolve job.attrs._id
            return

      @public @async getJob: Function,
        default: (queueName, jobId, options = {})->
          queueName = @fullQueueName queueName
          voAgenda = yield _agenda
          yield return Module::Promise.new (resolve, reject)->
            voAgenda.jobs {name: queueName, _id: jobId}, (err, [job] = [])->
              if err
                reject err
              else
                resolve if job?
                  if options.native then job else job.attrs
                else
                  null

      @public @async deleteJob: Function,
        default: (queueName, jobId)->
          job = yield @getJob queueName, jobId, native: yes
          if job?
            yield Module::Promise.new (resolve, reject)->
              job.remove (err)->
                if err?
                  reject err
                else
                  resolve()
            isDeleted = yes
          else
            isDeleted = no
          yield return isDeleted

      @public @async abortJob: Function,
        default: (queueName, jobId)->
          job = yield @getJob queueName, jobId, native: yes
          if job? and not job.attrs.failReason? and not job.attrs.failedAt?
            yield Module::Promise.new (resolve, reject)->
              job.fail new Error 'Job has been aborted'
              job.save (err)->
                if err?
                  reject err
                else
                  resolve()
          yield return

      @public @async allJobs: Function,
        default: (queueName, scriptName, options = {})->
          queueName = @fullQueueName queueName
          voAgenda = yield _agenda
          yield return Module::Promise.new (resolve, reject)->
            vhQuery = name: queueName
            if scriptName?
              vhQuery['data.scriptName'] = scriptName
            voAgenda.jobs vhQuery, (err, jobs)->
              if err?
                reject err
              else
                unless options.native
                  jobs = jobs.map (job) -> job.attrs
                resolve jobs ? []

      @public @async pendingJobs: Function,
        default: (queueName, scriptName, options = {})->
          queueName = @fullQueueName queueName
          voAgenda = yield _agenda
          yield return Module::Promise.new (resolve, reject)->
            vhQuery =
              name: queueName
              lastRunAt: $exists: no
              lastFinishedAt: $exists: no
              failedAt: $exists: no
            if scriptName?
              vhQuery['data.scriptName'] = scriptName
            voAgenda.jobs vhQuery, (err, jobs)->
              if err
                reject err
              else
                unless options.native
                  jobs = jobs.map (job) -> job.attrs
                resolve jobs ? []

      @public @async progressJobs: Function,
        default: (queueName, scriptName, options = {})->
          queueName = @fullQueueName queueName
          voAgenda = yield _agenda
          yield return Module::Promise.new (resolve, reject)->
            vhQuery =
              name: queueName
              lastRunAt: $exists: yes
              lastFinishedAt: $exists: no
              failedAt: $exists: no
            if scriptName?
              vhQuery['data.scriptName'] = scriptName
            voAgenda.jobs vhQuery, (err, jobs)->
              if err
                reject err
              else
                unless options.native
                  jobs = jobs.map (job) -> job.attrs
                resolve jobs ? []

      @public @async completedJobs: Function,
        default: (queueName, scriptName, options = {})->
          queueName = @fullQueueName queueName
          voAgenda = yield _agenda
          yield return Module::Promise.new (resolve, reject)->
            vhQuery =
              name: queueName
              lastRunAt: $exists: yes
              lastFinishedAt: $exists: yes
              failedAt: $exists: no
            if scriptName?
              vhQuery['data.scriptName'] = scriptName
            voAgenda.jobs vhQuery, (err, jobs)->
              if err
                reject err
              else
                unless options.native
                  jobs = jobs.map (job) -> job.attrs
                resolve jobs ? []

      @public @async failedJobs: Function,
        default: (queueName, scriptName, options = {})->
          queueName = @fullQueueName queueName
          voAgenda = yield _agenda
          yield return Module::Promise.new (resolve, reject)->
            vhQuery =
              name: queueName
              failedAt: $exists: yes
            if scriptName?
              vhQuery['data.scriptName'] = scriptName
            voAgenda.jobs vhQuery, (err, jobs)->
              if err
                reject err
              else
                unless options.native
                  jobs = jobs.map (job) -> job.attrs
                resolve jobs ? []


      @initializeMixin()
