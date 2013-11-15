require 'spec_helper'
require 'fakeredis'

describe Rack::Limit::Backends::Redis do
  include Rack::Test::Methods
  let(:target_app) { double(call: [200, {}, 'test app']) }
  let(:app) { Rack::Limit::Backends::Redis.new target_app, {rules: rules, cache: redis, key_prefix: :ratelimit} }
  let(:redis) { Redis.new }

  after { redis.flushall }

  describe 'required' do
    let(:rules) { [{'path' => '/api', 'required' => {'params' => {'api_key' => '403 Forbidden (api key required)'}}}] }

    it 'should do this' do
      get '/api'
      last_response.body.should == "403 Forbidden (api key required)\n"
      redis.keys.size.should == 0
    end
  end

  describe 'rate limit' do
    let(:rules) { [{'path' => '/api', 'strategy' => 'hourly', 'max' => '2'}] }

    it 'should rate limit' do
      get '/api'
      last_response.ok?.should be_true
      get '/api'
      last_response.ok?.should be_true
      get '/api'
      last_response.ok?.should_not be_true
      last_response.body.should == "403 Forbidden\n"
      redis.ttl('ratelimit:127.0.0.1').should_not == -1
    end
  end

  describe 'limit by' do
    let(:rules) { [{'path' => '/api', 'required' => {'params' => {'api_key' => '403 Forbidden (api key required)'}}, 'limit_by' => {'params' => 'api_key'}, 'max' => 3}] }
    it 'should limit by param api_key' do
      get '/api', {'api_key' => '123'}
      get '/api', {'api_key' => '123'}
      last_response.ok?.should be_true
    end

    it 'should limit by param api_key on post request' do
      post '/api', {'api_key' => '123'}
      last_response.ok?.should be_true
    end
  end
end
