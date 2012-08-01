require 'rspec'

module Log4ever
  class << self
    def config_xml
      File.dirname(__FILE__) + "/../config/log4r.xml"
    end
  end
end