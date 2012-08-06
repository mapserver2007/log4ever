require 'rspec'

module Log4ever
  class << self
    def config_xml
      File.dirname(__FILE__) + "/../config/log4r.xml"
    end
    
    def evernote_auth
      path = File.dirname(__FILE__) + "/../config/evernote.auth.yml"
      YAML.load_file(path)["auth_token"]
    end
  end
end