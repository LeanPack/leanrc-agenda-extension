{ expect, assert } = require 'chai'
sinon = require 'sinon'
_ = require 'lodash'
Agenda = require 'agenda'
LeanRC = require 'LeanRC'
AgendaExtension = require.main.require 'lib'
{ co } = LeanRC::Utils


describe 'AgendaResqueMixin', ->
  describe '.new', ->
    it 'should create resque instance', ->
      co ->
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        assert.instanceOf resque, TestResque
        yield return
  describe '#onRegister', ->
    facade = null
    KEY = 'TEST_AGENDA_RESQUE_MIXIN_001'
    after -> facade?.remove?()
    it 'should run on-register flow', ->
      co ->
        facade = LeanRC::Facade.getInstance KEY
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        configs = Test::Configuration.new Test::CONFIGURATION, Test::ROOT
        facade.registerProxy configs
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        resque.initializeNotifier KEY
        resque.onRegister()
        agenda = yield resque[TestResque.instanceVariables['_agenda'].pointer]
        assert.instanceOf agenda, Agenda
        assert.include agenda._name, require('os').hostname()
        assert.equal agenda._maxConcurrency, 16
        assert.equal agenda._defaultConcurrency, 16
        assert.equal agenda._lockLimit, 16
        assert.equal agenda._defaultLockLimit, 16
        assert.equal agenda._defaultLockLifetime, 5000
        yield return
  describe '#onRemove', ->
    facade = null
    KEY = 'TEST_AGENDA_RESQUE_MIXIN_002'
    after -> facade?.remove?()
    it 'should run on-remove flow', ->
      co ->
        facade = LeanRC::Facade.getInstance KEY
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        configs = Test::Configuration.new Test::CONFIGURATION, Test::ROOT
        facade.registerProxy configs
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        resque.initializeNotifier KEY
        resque.onRegister()
        agenda = yield resque[TestResque.instanceVariables['_agenda'].pointer]
        spyStop = sinon.spy agenda, 'stop'
        resque.onRemove()
        agenda = yield resque[TestResque.instanceVariables['_agenda'].pointer]
        assert.isTrue spyStop.called
        yield return
  describe '#ensureQueue', ->
    facade = null
    agenda = null
    queueNames = []
    KEY = 'TEST_AGENDA_RESQUE_MIXIN_003'
    after ->
      co ->
        collection = agenda?._mdb.collection 'delayedQueues'
        if collection?
          for name in queueNames
            yield collection.deleteOne { name }
        facade?.remove?()
        yield return
    it 'should create queue config', ->
      co ->
        facade = LeanRC::Facade.getInstance KEY
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        configs = Test::Configuration.new Test::CONFIGURATION, Test::ROOT
        facade.registerProxy configs
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        facade.registerProxy resque
        agenda = yield resque[TestResque.instanceVariables['_agenda'].pointer]
        { name, concurrency } = yield resque.ensureQueue 'TEST_QUEUE', 5
        queueNames.push name
        assert.equal name, 'Test|>TEST_QUEUE'
        assert.equal concurrency, 5
        collection = agenda._mdb.collection 'delayedQueues'
        count = yield collection.count { name }
        assert.equal count, 1
        { name, concurrency } = yield resque.ensureQueue 'TEST_QUEUE', 5
        queueNames.push name
        assert.equal name, 'Test|>TEST_QUEUE'
        assert.equal concurrency, 5
        collection = agenda._mdb.collection 'delayedQueues'
        count = yield collection.count { name }
        assert.equal count, 1
        yield return
  describe '#getQueue', ->
    facade = null
    agenda = null
    queueNames = []
    KEY = 'TEST_AGENDA_RESQUE_MIXIN_004'
    after ->
      co ->
        collection = agenda?._mdb.collection 'delayedQueues'
        if collection?
          for name in queueNames
            yield collection.deleteOne { name }
        facade?.remove?()
        yield return
    it 'should get queue', ->
      co ->
        facade = LeanRC::Facade.getInstance KEY
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        configs = Test::Configuration.new Test::CONFIGURATION, Test::ROOT
        facade.registerProxy configs
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        facade.registerProxy resque
        agenda = yield resque[TestResque.instanceVariables['_agenda'].pointer]
        yield resque.ensureQueue 'TEST_QUEUE', 5
        queue = yield resque.getQueue 'TEST_QUEUE'
        queueNames.push queue.name
        assert.propertyVal queue, 'name', 'Test|>TEST_QUEUE'
        assert.propertyVal queue, 'concurrency', 5
        yield return
  describe '#removeQueue', ->
    facade = null
    agenda = null
    queueNames = []
    KEY = 'TEST_AGENDA_RESQUE_MIXIN_005'
    after ->
      co ->
        collection = agenda?._mdb.collection 'delayedQueues'
        if collection?
          for name in queueNames
            yield collection.deleteOne { name }
        facade?.remove?()
        yield return
    it 'should remove queue', ->
      co ->
        facade = LeanRC::Facade.getInstance KEY
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        configs = Test::Configuration.new Test::CONFIGURATION, Test::ROOT
        facade.registerProxy configs
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        facade.registerProxy resque
        agenda = yield resque[TestResque.instanceVariables['_agenda'].pointer]
        { name } = yield resque.ensureQueue 'TEST_QUEUE', 5
        queueNames.push name
        queue = yield resque.getQueue 'TEST_QUEUE'
        assert.isDefined queue
        yield resque.removeQueue 'TEST_QUEUE'
        queue = yield resque.getQueue 'TEST_QUEUE'
        assert.isUndefined queue
        yield return
  describe '#allQueues', ->
    facade = null
    agenda = null
    queueNames = []
    KEY = 'TEST_AGENDA_RESQUE_MIXIN_006'
    after ->
      co ->
        collection = agenda?._mdb.collection 'delayedQueues'
        if collection?
          for name in queueNames
            yield collection.deleteOne { name }
        facade?.remove?()
        yield return
    it 'should get all queues', ->
      co ->
        facade = LeanRC::Facade.getInstance KEY
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        configs = Test::Configuration.new Test::CONFIGURATION, Test::ROOT
        facade.registerProxy configs
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        facade.registerProxy resque
        agenda = yield resque[TestResque.instanceVariables['_agenda'].pointer]
        { name } = yield resque.ensureQueue 'TEST_QUEUE_1', 1
        queueNames.push name
        { name } = yield resque.ensureQueue 'TEST_QUEUE_2', 2
        queueNames.push name
        { name } = yield resque.ensureQueue 'TEST_QUEUE_3', 3
        queueNames.push name
        { name } = yield resque.ensureQueue 'TEST_QUEUE_4', 4
        queueNames.push name
        { name } = yield resque.ensureQueue 'TEST_QUEUE_5', 5
        queueNames.push name
        { name } = yield resque.ensureQueue 'TEST_QUEUE_6', 6
        queueNames.push name
        queues = yield resque.allQueues()
        assert.includeDeepMembers queues, [
          name: 'Test|>TEST_QUEUE_1', concurrency: 1
        ,
          name: 'Test|>TEST_QUEUE_2', concurrency: 2
        ,
          name: 'Test|>TEST_QUEUE_3', concurrency: 3
        ,
          name: 'Test|>TEST_QUEUE_4', concurrency: 4
        ,
          name: 'Test|>TEST_QUEUE_5', concurrency: 5
        ,
          name: 'Test|>TEST_QUEUE_6', concurrency: 6
        ]
        yield return
  describe '#pushJob', ->
    facade = null
    agenda = null
    queueNames = []
    jobIds = []
    KEY = 'TEST_AGENDA_RESQUE_MIXIN_007'
    after ->
      co ->
        jobsCollection = agenda?._mdb.collection 'delayedJobs'
        if jobsCollection?
          for jobId in jobIds
            yield jobsCollection.deleteOne { _id: jobId }
        queuesCollection = agenda?._mdb.collection 'delayedQueues'
        if queuesCollection?
          for name in queueNames
            yield queuesCollection.deleteOne { name }
        facade?.remove?()
        yield return
    it 'should save new job', ->
      co ->
        facade = LeanRC::Facade.getInstance KEY
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        configs = Test::Configuration.new Test::CONFIGURATION, Test::ROOT
        facade.registerProxy configs
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        facade.registerProxy resque
        agenda = yield resque[TestResque.instanceVariables['_agenda'].pointer]
        { name } = yield resque.ensureQueue 'TEST_QUEUE_1', 1
        queueNames.push name
        DATA = data: 'data'
        DATE = new Date Date.now() + 60000
        jobId = yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT', DATA, DATE
        jobIds.push jobId
        jobsCollection = agenda?._mdb.collection 'delayedJobs'
        job = yield jobsCollection.findOne _id: jobId
        assert.include job,
          name: 'Test|>TEST_QUEUE_1'
          type: 'normal'
          priority: 0
        assert.equal job._id.toString(), jobId
        assert.equal job.nextRunAt.toISOString(), DATE.toISOString()
        assert.equal job.lastModifiedBy, agenda._name
        yield return
  ###
  describe '#getJob', ->
    jobId = null
    after ->
      db._jobs.remove jobId  if jobId?
      Queues.delete 'default'
      Queues.delete 'test_test_queue_1'
    it 'should get saved job', ->
      co ->
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        resque.onRegister()
        resque.ensureQueue 'TEST_QUEUE_1', 1
        DATA = data: 'data'
        DATE = new Date Date.now() + 60000
        jobId = yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT', DATA, DATE
        job = yield resque.getJob 'TEST_QUEUE_1', jobId
        assert.include job,
          _key: jobId.replace /^_jobs\//, ''
          _id: jobId
          status: 'pending'
          queue: 'test_test_queue_1'
          runs: 0
          delayUntil: DATE.getTime()
          maxFailures: 0
          repeatDelay: 0
          repeatTimes: 0
          repeatUntil: -1
        assert.deepEqual job.type, name: 'TEST_SCRIPT', mount: '/test'
        assert.deepEqual job.failures, []
        assert.deepEqual job.data, DATA
        yield return
  describe '#deleteJob', ->
    jobId = null
    after ->
      if jobId? and (try db._jobs.document jobId)
        db._jobs.remove jobId
      Queues.delete 'default'
      Queues.delete 'test_test_queue_1'
    it 'should remove saved job', ->
      co ->
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        resque.onRegister()
        resque.ensureQueue 'TEST_QUEUE_1', 1
        DATA = data: 'data'
        DATE = new Date Date.now() + 60000
        jobId = yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT', DATA, DATE
        job = yield resque.getJob 'TEST_QUEUE_1', jobId
        assert.include job,
          _key: jobId.replace /^_jobs\//, ''
          _id: jobId
          status: 'pending'
          queue: 'test_test_queue_1'
          runs: 0
          delayUntil: DATE.getTime()
          maxFailures: 0
          repeatDelay: 0
          repeatTimes: 0
          repeatUntil: -1
        assert.deepEqual job.type, name: 'TEST_SCRIPT', mount: '/test'
        assert.deepEqual job.failures, []
        assert.deepEqual job.data, DATA
        assert.isTrue yield resque.deleteJob 'TEST_QUEUE_1', jobId
        assert.isNull yield resque.getJob 'TEST_QUEUE_1', jobId
        yield return
  describe '#abortJob', ->
    jobId = null
    after ->
      if jobId? and (try db._jobs.document jobId)
        db._jobs.remove jobId
      Queues.delete 'default'
      Queues.delete 'test_test_queue_1'
    it 'should discard job', ->
      co ->
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        resque.onRegister()
        resque.ensureQueue 'TEST_QUEUE_1', 1
        DATA = data: 'data'
        DATE = new Date Date.now() + 60000
        jobId = yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT', DATA, DATE
        job = yield resque.getJob 'TEST_QUEUE_1', jobId
        assert.include job,
          _key: jobId.replace /^_jobs\//, ''
          _id: jobId
          status: 'pending'
          queue: 'test_test_queue_1'
          runs: 0
          delayUntil: DATE.getTime()
          maxFailures: 0
          repeatDelay: 0
          repeatTimes: 0
          repeatUntil: -1
        assert.deepEqual job.type, name: 'TEST_SCRIPT', mount: '/test'
        assert.deepEqual job.failures, []
        assert.deepEqual job.data, DATA
        yield resque.abortJob 'TEST_QUEUE_1', jobId
        job = yield resque.getJob 'TEST_QUEUE_1', jobId
        assert.include job,
          _key: jobId.replace /^_jobs\//, ''
          _id: jobId
          status: 'failed'
          queue: 'test_test_queue_1'
          runs: 0
          delayUntil: DATE.getTime()
          maxFailures: 0
          repeatDelay: 0
          repeatTimes: 0
          repeatUntil: -1
        assert.deepEqual job.type, name: 'TEST_SCRIPT', mount: '/test'
        assert.property job.failures[0], 'stack'
        assert.propertyVal job.failures[0], 'message', 'Job aborted.'
        assert.propertyVal job.failures[0], 'name', 'Error'
        assert.deepEqual job.data, DATA
        yield return
  describe '#allJobs', ->
    ids = []
    after ->
      for id in ids
        if id? and (try db._jobs.document id)
          db._jobs.remove id
      Queues.delete 'default'
      Queues.delete 'test_test_queue_1'
      Queues.delete 'test_test_queue_2'
    it 'should list all jobs', ->
      co ->
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        resque.onRegister()
        resque.ensureQueue 'TEST_QUEUE_1', 1
        resque.ensureQueue 'TEST_QUEUE_2', 1
        DATA = data: 'data'
        DATE = new Date Date.now() + 3600000
        ids.push yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_2', DATA, DATE
        ids.push yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_1', DATA, DATE
        ids.push jobId = yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_2', DATA, DATE
        ids.push yield resque.pushJob 'TEST_QUEUE_2', 'TEST_SCRIPT_1', DATA, DATE
        ids.push yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_2', DATA, DATE
        ids.push yield resque.pushJob 'TEST_QUEUE_2', 'TEST_SCRIPT_1', DATA, DATE
        yield resque.deleteJob 'TEST_QUEUE_1', jobId
        jobs = yield resque.allJobs 'TEST_QUEUE_1'
        assert.lengthOf jobs, 3
        jobs = yield resque.allJobs 'TEST_QUEUE_1', 'TEST_SCRIPT_2'
        assert.lengthOf jobs, 2
        yield return
  describe '#pendingJobs', ->
    ids = []
    after ->
      for id in ids
        if id? and (try db._jobs.document id)
          db._jobs.remove id
      Queues.delete 'default'
      Queues.delete 'test_test_queue_1'
      Queues.delete 'test_test_queue_2'
    it 'should list pending jobs', ->
      co ->
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        resque.onRegister()
        resque.ensureQueue 'TEST_QUEUE_1', 1
        resque.ensureQueue 'TEST_QUEUE_2', 1
        DATA = data: 'data'
        DATE = new Date()
        ids.push yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_1', DATA, DATE
        ids.push yield resque.pushJob 'TEST_QUEUE_2', 'TEST_SCRIPT_1', DATA, DATE
        ids.push jobId = yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_1', DATA, DATE
        ids.push yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_2', DATA, DATE
        job = yield resque.getJob 'TEST_QUEUE_1', jobId
        db._jobs.update job._key, status: 'running'
        jobs = yield resque.pendingJobs 'TEST_QUEUE_1'
        assert.lengthOf jobs, 2
        jobs = yield resque.pendingJobs 'TEST_QUEUE_1', 'TEST_SCRIPT_2'
        assert.lengthOf jobs, 1
        yield return
  describe '#progressJobs', ->
    ids = []
    after ->
      for id in ids
        if id? and (try db._jobs.document id)
          db._jobs.remove id
      Queues.delete 'default'
      Queues.delete 'test_test_queue_1'
      Queues.delete 'test_test_queue_2'
    it 'should list runnning jobs', ->
      co ->
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        resque.onRegister()
        resque.ensureQueue 'TEST_QUEUE_1', 1
        resque.ensureQueue 'TEST_QUEUE_2', 1
        DATA = data: 'data'
        DATE = new Date()
        ids.push yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_1', DATA, DATE
        ids.push yield resque.pushJob 'TEST_QUEUE_2', 'TEST_SCRIPT_1', DATA, DATE
        ids.push jobId = yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_1', DATA, DATE
        ids.push yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_2', DATA, DATE
        job = yield resque.getJob 'TEST_QUEUE_1', jobId
        db._jobs.update job._key, status: 'progress'
        jobs = yield resque.progressJobs 'TEST_QUEUE_1'
        assert.lengthOf jobs, 1
        jobs = yield resque.progressJobs 'TEST_QUEUE_1', 'TEST_SCRIPT_2'
        assert.lengthOf jobs, 0
        yield return
  describe '#completedJobs', ->
    ids = []
    after ->
      for id in ids
        if id? and (try db._jobs.document id)
          db._jobs.remove id
      Queues.delete 'default'
      Queues.delete 'test_test_queue_1'
      Queues.delete 'test_test_queue_2'
    it 'should list complete jobs', ->
      co ->
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        resque.onRegister()
        resque.ensureQueue 'TEST_QUEUE_1', 1
        resque.ensureQueue 'TEST_QUEUE_2', 1
        DATA = data: 'data'
        DATE = new Date()
        ids.push yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_1', DATA, DATE
        ids.push yield resque.pushJob 'TEST_QUEUE_2', 'TEST_SCRIPT_1', DATA, DATE
        ids.push jobId = yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_1', DATA, DATE
        ids.push yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_2', DATA, DATE
        job = yield resque.getJob 'TEST_QUEUE_1', jobId
        db._jobs.update job._key, status: 'complete'
        jobs = yield resque.completedJobs 'TEST_QUEUE_1'
        assert.lengthOf jobs, 1
        jobs = yield resque.completedJobs 'TEST_QUEUE_1', 'TEST_SCRIPT_2'
        assert.lengthOf jobs, 0
        yield return
  describe '#failedJobs', ->
    ids = []
    after ->
      for id in ids
        if id? and (try db._jobs.document id)
          db._jobs.remove id
      Queues.delete 'default'
      Queues.delete 'test_test_queue_1'
      Queues.delete 'test_test_queue_2'
    it 'should list failed jobs', ->
      co ->
        class Test extends LeanRC
          @inheritProtected()
          @include AgendaExtension
          @root "#{__dirname}/config/root"
        Test.initialize()
        class TestResque extends LeanRC::Resque
          @inheritProtected()
          @include Test::AgendaResqueMixin
          @module Test
        TestResque.initialize()
        resque = TestResque.new 'TEST_AGENDA_RESQUE_MIXIN'
        resque.onRegister()
        resque.ensureQueue 'TEST_QUEUE_1', 1
        resque.ensureQueue 'TEST_QUEUE_2', 1
        DATA = data: 'data'
        DATE = new Date()
        ids.push yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_1', DATA, DATE
        ids.push yield resque.pushJob 'TEST_QUEUE_2', 'TEST_SCRIPT_1', DATA, DATE
        ids.push jobId = yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_1', DATA, DATE
        ids.push yield resque.pushJob 'TEST_QUEUE_1', 'TEST_SCRIPT_2', DATA, DATE
        job = yield resque.getJob 'TEST_QUEUE_1', jobId
        db._jobs.update job._key, status: 'failed'
        jobs = yield resque.failedJobs 'TEST_QUEUE_1'
        assert.lengthOf jobs, 1
        jobs = yield resque.failedJobs 'TEST_QUEUE_1', 'TEST_SCRIPT_2'
        assert.lengthOf jobs, 0
        yield return
  ###
