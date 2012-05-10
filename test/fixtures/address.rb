# turns everything into the same object
class AddressXMLFormatter < ActiveResource::Middleware::Formats::XmlFormat

  def decode(xml)
    data = ActiveResource::Middleware::Formats::XmlFormat.decode(xml)
    # process address fields
    data.each do |address|
      address['city_state'] = "#{address['city']}, #{address['state']}"
    end
    data
  end

end

class AddressResource < ActiveResource::Base
  self.element_name = "address"
  self.format = AddressXMLFormatter
  self.adapter = :test
end
