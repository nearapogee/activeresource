class Post < ActiveResource::Base
  self.site = "http://37s.sunrise.i:3000"
  self.adapter = :test
end
