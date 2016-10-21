require 'spec_helper'
require 'sidekiq/testing'
require 'rspec-sidekiq'
require 'kungfuig/jobber'

describe Kungfuig::Jobber do
  let(:test) { Test.new }
  let(:test_module_test) { TestModuleTest.new }
  let!(:test_worker_yaml) { "'Test':\n  'yo': 'TestWorker'" }
  let!(:test_worker_string_yaml) { "'Test':\n  'yo': 'TestWorkerString'" }
  let!(:test_worker_harm_yaml) { "'Test':\n  'yo': 'TestWorkerHARM'" }
  let!(:test_module_test_yaml) { "'TestModuleTest':\n  'yo': 'TestWorker'" }
  let!(:test_worker_param_yaml) { "'Test':\n  'yo':\n    'class': 'TestWorker'\n    'delay': 3" }

  it 'accepts YAML for bulk jobber' do
    bulk = Kungfuig::Jobber.bulk(test_worker_yaml)
    expect(bulk).to be_truthy
    expect(bulk.inspect).to match(/"Test"=>\[{:yo=>1}\]/)

    # FIXME: test job scheduling
    expect(test.yo(42)).to eq [42, [], {}, nil]
    expect(test.yo(42, :p1, :p2)).to eq [42, [:p1, :p2], {}, nil]
    expect(test.yo(42, :p1, :p2, sp1: 1, sp2: 1)).to eq [42, [:p1, :p2], {sp1: 1, sp2: 1}, nil]
  end

  it 'accepts YAML for bulk jobber (simple string)' do
    bulk = Kungfuig::Jobber.bulk(test_worker_string_yaml)
    expect(bulk).to be_truthy
    expect(bulk.inspect).to match(/"Test"=>\[{:yo=>1}\]/)

    expect(test.yo(42)).to eq [42, [], {}, nil]
    expect(test.yo(42, :p1, :p2)).to eq [42, [:p1, :p2], {}, nil]
    expect(test.yo(42, :p1, :p2, sp1: 1, sp2: 1)).to eq [42, [:p1, :p2], {sp1: 1, sp2: 1}, nil]
  end

  it 'logs an error but does not fail on wrong aspects in YAML for bulk jobber' do
    expect(Kungfuig::Jobber.bulk(test_worker_harm_yaml).inspect).to match(/"Test"=>\[{:yo=>1}\]/)
    expect { test.yo(42) }.to output(%r{kungfuig/spec/jobber_spec.rb}).to_stdout # prints a backtrace
  end

  it 'schedules sidekiq jobs on execution' do
    expect(Kungfuig::Jobber.bulk(test_worker_yaml)).to be_truthy
    expect(TestWorker.jobs.size).to eq 0

    [[42], [42, :p1, :p2], [42, :p1, :p2, sp1: 1, sp2: 1]].each.with_index do |args, idx|
      expect(TestWorker.jobs.size).to eq idx
      expect(test.yo(args)).to be_truthy
      sleep 0.1
      expect(TestWorker.jobs.size).to eq(idx + 1)
    end
    expect(TestWorker.jobs.size).to eq 3
    TestWorker.drain
    expect(TestWorker.jobs.size).to eq 0
  end

  it 'handles pointcuts from included modules properly' do
    expect(Kungfuig::Jobber.bulk(test_module_test_yaml)).to be_truthy
    expect(TestWorker.jobs.size).to eq 0

    [[42], [42, :p1, :p2], [42, :p1, :p2, sp1: 1, sp2: 1]].each.with_index do |args, idx|
      expect(TestWorker.jobs.size).to eq idx
      expect(test_module_test.yo(args)).to be_truthy
      sleep 0.1
      expect(TestWorker.jobs.size).to eq(idx + 1)
    end
    expect(TestWorker.jobs.size).to eq 3
    TestWorker.drain
    expect(TestWorker.jobs.size).to eq 0
  end

  it 'stacks subsequent same jobs and execute the only one after 1 minute' do
    Sidekiq::Testing.inline! do
      expect(Kungfuig::Jobber.bulk(test_worker_param_yaml)).to be_truthy
      expect(test.yo([42, :p1, :p2, sp1: 1, sp2: 1])).to be_truthy
    end
  end
end
