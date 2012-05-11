module ActiveResource
  class LogSubscriber < ActiveSupport::LogSubscriber
    def request(event)
      result = event.payload[:result]
      duration = event.payload[:duration]
      info "#{event.payload[:method].to_s.upcase} #{event.payload[:request_uri]}"
      info "--> %d %s %d (%.1fms)" % [result.status, result.status, result.body.to_s.length, duration] 
    end

    def logger
      ActiveResource::Base.logger
    end
  end
end

ActiveResource::LogSubscriber.attach_to :active_resource
