require 'rspec'

module Log4ever
  class << self
    def config_xml
      File.dirname(__FILE__) + "/../config/log4r.xml"
    end

    def evernote_auth
      file = File.dirname(__FILE__) + "/../config/evernote.auth.yml"
      obj = File.exist?(file) ? YAML.load_file(file) : ENV
      obj["auth_token"]
    end
  end
end
