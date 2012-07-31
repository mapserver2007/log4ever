# -*- coding: utf-8 -*-
$: << File.dirname(__FILE__) + "/evernote/lib"
$: << File.dirname(__FILE__) + "/evernote/lib/thrift"
$: << File.dirname(__FILE__) + "/evernote/lib/Evernote/EDAM"
require 'log4r/outputter/evernoteoutputter'
require "thrift/types"
require "thrift/struct"
require "thrift/protocol/base_protocol"
require "thrift/protocol/binary_protocol"
require "thrift/transport/base_transport"
require "thrift/transport/http_client_transport"
require "Evernote/EDAM/user_store"
require "Evernote/EDAM/user_store_constants.rb"
require "Evernote/EDAM/note_store"
require "Evernote/EDAM/limits_constants.rb"
require 'active_support'
require 'active_support/time'
require 'active_support/core_ext'

module Log4r
  
  class EvernoteOutputter < Outputter
    
    def initialize(_name, hash = {})
      super(_name, hash)
      validate(hash)
    end
    
    # validation of evernote parameters
    def validate(hash)
      @env = hash[:env] || hash['env'] || 'sandbox'
      if @env != 'sandbox' && @env != 'production'
        raise ArgumentError, "Must evernote environment 'sandbox' or 'production'" 
      end
    end
    
    def canonical_log(logevent)
      synch {
        
        
        
      }
    end
    
    
    
  end
  
end


module Log4ever
  VERSION = '0.0.1'
end

# module Log4ever
  # include Log4r
  # VERSION = '0.0.1'
  # class Logger < Log4r::Logger
    # def add(*_outputters)
      # super(*_outputters)
    # end
  # end
# end