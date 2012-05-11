module ActiveResource
  class Stubs

    def self.add
      @stubs ||= Faraday::Adapter::Test::Stubs.new
      yield @stubs
    end

    def self.stubs
      @stubs ||= Faraday::Adapter::Test::Stubs.new
    end

    def self.clear
      @stubs = Faraday::Adapter::Test::Stubs.new
    end

    def self.set
      clear
      yield @stubs
    end

  end
end
