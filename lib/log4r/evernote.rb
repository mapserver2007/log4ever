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

module Log4ever
  VERSION = '0.0.5'
  class TypeError < StandardError; end
  module ShiftAge
    DAILY = 1
    WEEKLY = 2
    MONTHLY = 3
  end
end

module Log4r
  include Log4ever
  class MyEvernote
    @@note_store = nil
    
    def initialize(env, auth_token)
      if @@note_store.nil?
        @env = env
        @@auth_token = auth_token
        userStoreTransport = Thrift::HTTPClientTransport.new(@env)
        userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
        user_store = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)
        noteStoreUrl = user_store.getNoteStoreUrl(@@auth_token)
        noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
        noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
        @@note_store = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)
      end
    end

    # get registered notebook or create new notebook
    def get_notebook(notebook_name, stack_name)
      Notebook.new(notebook_name, stack_name)
    end

    # get registered note or create new note
    def get_note(notebook_obj)
      Note.new(notebook_obj)
    end
    
    # get registerd tag list
    def get_tags(tag_names)
      tag_names.map do |tag_name|
        get_tag(tag_name) || create_tag(tag_name)
      end
    end

    # get registered tag object
    def get_tag(tag_name)
      return if tag_name.empty?
      tag_name = to_ascii(tag_name)
      @@note_store.listTags(@@auth_token).each do |tag|
        if tag_name == tag.name
          Logger.log_internal { "Get tag: #{tag_name}" }
          return tag
        end
      end
      nil
    end
    
    # create tag object
    def create_tag(tag_name)
      tag = Evernote::EDAM::Type::Tag.new
      tag.name = tag_name
      tag_obj = @@note_store.createTag(@@auth_token, tag)
      Logger.log_internal { "Create tag: #{tag_name}" }
      tag_obj
    end

    # encode for evernote internal charset
    def to_ascii(str)
      str.force_encoding("ASCII-8BIT") unless str.nil?
    end
  end

  class Notebook < MyEvernote
    def initialize(notebook_name, stack_name)
      return unless @notebook.nil?
      get(notebook_name, stack_name) || create(notebook_name, stack_name)
    end
    
    # get notebook object
    def getNotebookObject; @notebook end
    
    # get notebook
    def get(notebook_name, stack_name)
      @@note_store.listNotebooks(@@auth_token).each do |notebook|
        notebook_name = to_ascii(notebook_name)
        stack_name = to_ascii(stack_name)
        if notebook.name == notebook_name && notebook.stack == stack_name
          Logger.log_internal { "Get notebook: #{stack_name}/#{notebook_name}" }
          @notebook = notebook
          break
        end
      end
      @notebook
    end
    
    # create notebook
    def create(notebook_name, stack_name)
      notebook = Evernote::EDAM::Type::Notebook.new
      notebook.name = notebook_name
      notebook.stack = stack_name
      @notebook = @@note_store.createNotebook(@@auth_token, notebook)
      Logger.log_internal { "Create notebook: #{stack_name}/#{notebook_name}" }
      @notebook
    end
  
    # notebook guid
    def guid; @notebook.guid end

    # clear notebook object
    def clear
      @notebook = nil
      initialize(@env, @@auth_token)
    end
  end

  class Note < MyEvernote
    XML_TEMPLATE_BYTE = 237
    
    def initialize(notebook)
      return unless @params.nil? || @params.empty?
      @params = {}
      @notebook = notebook
      if !@notebook.kind_of? Notebook
        raise TypeError, 'Expected kind of Notebook, got #{@notebook.class}', caller
      elsif !@notebook.respond_to? 'guid'
        raise NoMethodError, '#{@notebook.class} do not has method: guid', caller
      end
      getNote
    end
    
    # get note object
    def getNoteObject; @note end
    
    # content size
    def size
      content.bytesize > 0 ? content.bytesize - XML_TEMPLATE_BYTE : 0
    end
    
    # note guid
    def guid; @note.guid end

    # set new title
    def title=(str)
      @params[:title] = to_ascii(str)
    end

    # set tags
    def tags=(list)
      @params[:tagGuids] = list
    end

    # append content
    def addContent(text)
      new_html = "<div style='font-family: Courier New'>#{text}</div>"
      content_xml.at('en-note').inner_html += new_html
      @params[:content] = @content_ = to_ascii(content_xml.to_xml)
    end
    
    # set new content
    def content=(text)
      @params[:content] = @content_ = to_ascii("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n" +
      "<!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\">\n" +
      "<en-note style=\"word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space;\">\n" +
      "<div style=\"font-family: Courier New\">#{text}</div></en-note>")
    end 

    # create note
    def create
      @@note_store.createNote(@@auth_token, createNote)
      clear
    end

    # update note
    def update
      @@note_store.updateNote(@@auth_token, updateNote)
    end

    # clear note object
    def clear
      @params = {}
      @note = @content_ = @content_xml = nil
      initialize(@notebook)
    end
    
    def getNote
      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      filter.order = Evernote::EDAM::Type::NoteSortOrder::CREATED
      filter.notebookGuid = @notebook.guid
      filter.timeZone = "Asia/Tokyo"
      filter.ascending = false # descending
      note_list = @@note_store.findNotes(@@auth_token, filter, 0, 1)
      if note_list.notes.empty?
        Logger.log_internal { "Note not found at #{@notebook.guid}" }
        @note = Evernote::EDAM::Type::Note.new
      else  
        @note = note_list.notes[0]
      end
      @note
    end
    
    # create note object
    def createNote
      @note = Evernote::EDAM::Type::Note.new
      @note.notebookGuid = @notebook.guid
      @params.each{|method, value| @note.send("#{method.to_s}=", value)}
      @note
    end
    
    # get note object
    def updateNote
      getNote if @note.nil?
      @note.content = @params[:content]
      @note
    end
    
    # get created time 
    def created_at
      time = @note.created.to_s
      ut = time.slice(0, time.length - 3)
      Time.at(ut.to_f)
    end
    
    # get note content text
    def content
      return @content_ unless @content_.nil?
      @content_ = !@note.nil? && !@note.guid.nil? ? @@note_store.getNoteContent(@@auth_token, @note.guid) : ""
    end

    # get note content xml object
    def content_xml
      return @content_xml unless @content_xml.nil?
      @content_xml = Nokogiri::XML(content)
    end
  end
end