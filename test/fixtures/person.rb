module Test
  class Auth < Faraday::Middleware
    def initialize(app, token)
      @app = app
      @token = token
    end
    def call(env)
      env[:request_headers]['X-Auth'] = @token
      @app.call(env)
    end
  end
end
class Person < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  self.adapter = :test

  scope :bogus, lambda {}
  scope :auth, lambda { |token| middleware.insert 0, Test::Auth, token }
end

module External
  class Person < ActiveResource::Base
    self.site = "http://atq.caffeine.intoxication.it"
  end
end

