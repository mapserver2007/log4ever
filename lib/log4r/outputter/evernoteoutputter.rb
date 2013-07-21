# -*- coding: utf-8 -*-
require 'nokogiri'
require 'log4r/outputter/outputter'
require "log4r/staticlogger"
require 'active_support'
require 'active_support/time'
require 'active_support/core_ext'

module Log4r
  class EvernoteOutputter < Outputter

    def initialize(_name, hash = {})
      super(_name, hash)
      validate(hash)
    end
    
    # synchronize note
    def sync
      @note = @evernote.note(@notebook)
      @tag = @evernote.tag(@note)
      @tag.names = @tags
      set_maxsize(@hash) # for rolling
      set_shift_age(@hash) # for rolling
    end

    # validation of evernote parameters
    def validate(hash)
      is_sandbox = hash[:sandbox] || hash['sandbox'] || false
      raise ArgumentError, "Sandbox must be type of boolean" unless is_sandbox == false || is_sandbox == true
      @auth_token = hash[:auth_token] || hash['auth_token'] || ""
      raise ArgumentError, "Must specify from auth token" if @auth_token.empty?
      notebook_name = hash[:notebook] || hash['notebook'] || ""
      raise ArgumentError, "Must specify from notebook" if notebook_name.empty?
      stack_name = hash[:stack] || hash['stack']
      @evernote = Log4ever::Evernote.new(@auth_token, is_sandbox)
      @tags = hash[:tags] || hash['tags'] || []
      notebook = @evernote.notebook
      @notebook = notebook.get(notebook_name, stack_name)
      @hash = hash
      sync
    end

    def canonical_log(logevent); super end

    # write log
    def write(content)
      sync
      if note_size_requires_roll? || time_requires_roll? || different_tag?
        create_log(content)
      else
        update_log(content)
      end
    end

    private
    # write log to note
    def create_log(content)
      @note.clear
      @note.title = @name + " - " + Time.now.strftime("%Y-%m-%d %H:%M:%S")
      @note.tags = @tag.get
      @note.content = content
      @note.create
      Logger.log_internal { "Create note: #{@note.guid}" }
    end
    
    # update log in note
    def update_log(content)
      @note.addContent(content)
      @note.tags = @tag.get
      @note.update
      Logger.log_internal { "Update note: #{@note.guid}" }
    end
    
    # more expensive, only for startup
    def note_size_requires_roll?
      @note.size == 0 || (@maxsize > 0 && @note.size >= @maxsize)
    end

    # whether or not to rotate
    def time_requires_roll?
      !@endTime.nil? && Time.now.to_i >= @endTime
    end

    # diff note's tag and register tag 
    def different_tag?
      note_tags = @note.tags || []
      tag = @tag.get || []
      (note_tags - tag).size != 0 || (tag - note_tags).size != 0
    end
  
    # max amount of log in note
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
    
    # rolling interval
    def set_shift_age(options)
      if options.has_key?(:shift_age) || options.has_key?('shift_age')
        _shift_age = (options[:shift_age] or options['shift_age']).to_i
        if _shift_age.class != Fixnum
          raise TypeError, "Argument 'shift_age' must be an Fixnum", caller
        end
        unless _shift_age.nil?
          unless [Log4ever::ShiftAge::DAILY, Log4ever::ShiftAge::WEEKLY,
              Log4ever::ShiftAge::MONTHLY].include? _shift_age
            raise TypeError, "Argument 'shift_age' must be > 0", caller
          end
          created_at = @note.created_at
          case _shift_age
          when Log4ever::ShiftAge::DAILY
            tomorrow = Time.local(created_at.tomorrow.year, created_at.tomorrow.month, created_at.tomorrow.day)
            @endTime = tomorrow.to_i
          when Log4ever::ShiftAge::WEEKLY
            next_week = Time.local(created_at.next_week.year, created_at.next_week.month, created_at.next_week.day)
            @endTime = next_week.to_i
          when Log4ever::ShiftAge::MONTHLY
            next_month = Time.local(created_at.next_month.year, created_at.next_month.month, created_at.next_month.day)
            @endTime = next_month.to_i
          else
            raise TypeError, "Argument 'shift_age' must be '1' or '2' or '3'", caller
          end
        end
      end
    end
  end
end