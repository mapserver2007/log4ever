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
      @notebook = hash[:notebook] || hash['notebook'] || ""
      raise ArgumentError, "Must specify from notebook" if @notebook.empty?
      @tags = hash[:tags] || hash['tags'] || []
      @stack = hash[:stack] || hash['stack']
      @evernote = EvernoteRegister.new(@env, @auth_token)
    end

    def canonical_log(logevent)
      synch { create_note(format(logevent)) }
    end

    def create_note(content)
      # TODO
      # 存在しないノート、Stackの場合、raise
      #
      @evernote.add_note({
        :notebook => @notebook,
        :stack => @stack,
        :content => content,
        :tags => ['Log']
      })
      
    end

    

  end
  
  class EvernoteRegister
    def initialize(env, auth_token)
      @auth_token = auth_token
      userStoreTransport = Thrift::HTTPClientTransport.new(env)
      userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
      user_store = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)
      noteStoreUrl = user_store.getNoteStoreUrl(@auth_token)
      noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
      noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
      @note_store = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
    end
    
    def add_note(params)
      # TODO　パフォーマンス的にもっとよくしたい。例えば毎回get_noteするのはやめる。
      
      
      
      # 検索条件
      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      filter.order = Evernote::EDAM::Type::NoteSortOrder::CREATED
      filter.notebookGuid = get_notebook_guid(params[:notebook], params[:stack])
      filter.timeZone = "Asia/Tokyo"
      filter.ascending = false # descending
      # ノート取得
      note_list = @note_store.findNotes(@auth_token, filter, 0, 1)
      note = note_list.notes[0] || Evernote::EDAM::Type::Note.new
      note.title = to_ascii("test") if note.title.nil?
      content = @note_store.getNoteContent(@auth_token, note.guid)
      note.content = create_content(content, params[:content])
      note.notebookGuid  = get_notebook_guid(params[:notebook], params[:stack])
      note.tagGuids = get_tag_guid(params[:tags])
      @note_store.updateNote(@auth_token, note)
    end
    
    def get_notebook_guid(notebook_name, stack_name = nil)
      notebook_name = to_ascii(notebook_name)
      stack_name = to_ascii(stack_name)
      @note_store.listNotebooks(@auth_token).each do |notebook|
        if notebook.name == notebook_name && notebook.stack == stack_name
          return notebook.guid
        end
      end
    end
    
    def create_content(xml_str, log_content)
      xml = Nokogiri::XML(xml_str)
      content = xml.at("en-note").inner_html + "<div style=\"font-family:'Courier New'\"><![CDATA[#{log_content}]]></div>"
      xml.at("en-note").inner_html = content
      to_ascii(xml.to_s)
    end
    
    def get_tag_guid(tag_list)
      return if tag_list.empty?
      tag_list.map!{|tag| to_ascii(tag)}
      @note_store.listTags(@auth_token).each_with_object [] do |tag, list|
        if tag_list.include? tag.name
          list << tag.guid
        end
      end
    end
    
    def to_ascii(str)
      str.force_encoding("ASCII-8BIT") unless str.nil?
    end
  end
  
  
end