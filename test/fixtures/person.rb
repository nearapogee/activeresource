class Person < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  self.adapter = :test
end

module External
  class Person < ActiveResource::Base
    self.site = "http://atq.caffeine.intoxication.it"
  end
end

