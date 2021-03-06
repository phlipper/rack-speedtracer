require 'spec_helper'

describe Rack::SpeedTracer do
  let(:app) { [200, {'Content-Type' => 'text/plain'}, 'Hello World'] }

  describe 'middleware' do
    it 'take a backend and returns a middleware component' do
      Rack::SpeedTracer.new(app).should respond_to(:call)
    end

    it 'take an options Hash' do
      lambda { Rack::SpeedTracer.new(app, {}) }.should_not raise_error(ArgumentError)
    end

    it 'takes a block' do
      db = {}
      middleware = Rack::SpeedTracer.new(app) do |tracer|
        tracer.db = db
      end
      middleware.db.should == db
    end

    context 'storage engine' do
      it 'takes an optional storage class' do
        class SomeStorageClass
          def initialize(options);end
        end
        st = Rack::SpeedTracer.new(app, :storage => SomeStorageClass)
        st.db.class.should == SomeStorageClass
      end

      it 'should default to memory storage' do
        st = Rack::SpeedTracer.new(app)
        st.db.class.should == Rack::SpeedTracer::Storage::Memory
      end

      it 'should accept redis storage' do
        st = Rack::SpeedTracer.new(app, :storage => Rack::SpeedTracer::Storage::Redis)
        st.db.class.should == Rack::SpeedTracer::Storage::Redis
      end
    end
  end

  describe 'response' do
    it 'should set the X-TraceUrl header after rendering the response' do
      respond_with(200)
      response = get('/')

      response.headers.should include 'X-TraceUrl'
      response.headers['X-TraceUrl'].should match(/^\/speedtracer\?id=/)
    end

    it 'should respond with 200 to HEAD requests to the speedtracer endpoint' do
      respond_with(200)
      response = head('/speedtracer?id=test')

      response.status.should == 200
      response.headers['Content-Length'].to_i.should == 0
    end

    it 'should return a stored trace in JSON format' do
      sample_trace = Yajl::Encoder.encode({'trace' => {}})

      respond_with(200)
      response = get('/speedtracer?id=test') do |st|
        st.db['test'] = sample_trace
      end

      response.body.should == sample_trace
    end

    it 'should return 404 on missing trace' do
      response = get('/speedtracer?id=test-missing')
      response.status.should == 404
    end
  end
end
