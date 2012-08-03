# -*- coding: utf-8 -*-
require 'nokogiri'
require 'log4r/outputter/outputter'
require "log4r/staticlogger"

module Log4r
  class EvernoteOutputter < Outputter
    SANDBOX_HOST = 'sandbox.evernote.com'
    PRODUCTION_HOST = 'www.evernote.com'

    def initialize(_name, hash = {})
      super(_name, hash)
      validate(hash)
    end

    # validation of evernote parameters
    def validate(hash)
      set_maxsize(hash) # for rolling
      set_maxtime(hash) # for rolling

      env = hash[:env] || hash['env'] || 'sandbox'
      if env == 'sandbox'
        @env = "https://#{SANDBOX_HOST}/edam/user"
      elsif env == 'production'
        @env = "https://#{PRODUCTION_HOST}/edam/user"
      else
        raise ArgumentError, "Must specify from env 'sandbox' or 'production'"
      end
      @auth_token = hash[:auth_token] || hash['auth_token'] || ""
      raise ArgumentError, "Must specify from auth token" if @auth_token.empty?
      @evernote = MyEvernote.new(@env, @auth_token)
      notebook = hash[:notebook] || hash['notebook'] || ""
      raise ArgumentError, "Must specify from notebook" if notebook.empty?
      #@tags = hash[:tags] || hash['tags'] || []
      tags = @evernote.get_tags(hash[:tags] || hash['tags'] || [])
      stack = hash[:stack] || hash['stack']
      @evernote = MyEvernote.new(@env, @auth_token)
      @notebook = @evernote.get_notebook(notebook, stack)
      @note = @evernote.get_note(@notebook)
      @tags = tags.map{|tag_obj| tag_obj.guid}
    end

    def canonical_log(logevent); super end

    def write(content)
      @content = content
      if note_size_requires_roll? || time_requires_roll? || @note.size == 0
        p "create"
        create_log
      else
        p "update"
        update_log
      end
    end

    private
    def create_log
      @note.clear
      @note.title = @name + " - " + Time.now.strftime("%Y-%m-%d %H:%M:%S")
      @note.tags = @tags
      @note.content = @content
      @note.create
      Logger.log_internal { "Create note: #{@note.guid}" }
    end
    
    def update_log
      @note.addContent(@content)
      @note.update
      Logger.log_internal { "Update note: #{@note.guid}" }
    end
    
    # more expensive, only for startup
    def note_size_requires_roll?
      @maxsize > 0 && @note.size >= @maxsize
    end

    def time_requires_roll?
      # TODO
    end

    def set_maxsize(options)
      if options.has_key?(:maxsize) || options.has_key?('maxsize')
        maxsize = options[:maxsize] || options['maxsize']

        multiplier = 1
        if (maxsize =~ /\d+KB/)
          multiplier = 1024
        elsif (maxsize =~ /\d+MB/)
          multiplier = 1024 * 1024
        elsif (maxsize =~ /\d+GB/)
          multiplier = 1024 * 1024 * 1024
        end

        _maxsize = maxsize.to_i * multiplier

        if _maxsize.class != Fixnum and _maxsize.class != Bignum
          raise TypeError, "Argument 'maxsize' must be an Fixnum", caller
        end
        if _maxsize == 0
          raise TypeError, "Argument 'maxsize' must be > 0", caller
        end
        @maxsize = _maxsize
      else
        @maxsize = 0
      end
    end

    def set_maxtime(options)
      if options.has_key?(:maxtime) || options.has_key?('maxtime')
        _maxtime = (options[:maxtime] or options['maxtime']).to_i
        if _maxtime.class != Fixnum
          raise TypeError, "Argument 'maxtime' must be an Fixnum", caller
        end
        if _maxtime == 0
          raise TypeError, "Argument 'maxtime' must be > 0", caller
        end
        @maxtime = _maxtime
        @startTime = Time.now
      else
        @maxtime = 0
        @startTime = 0
      end
    end

  end


end