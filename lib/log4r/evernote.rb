# -*- coding: utf-8 -*-
require 'log4r/outputter/evernoteoutputter'
require 'evernote_oauth'

module Log4ever
  VERSION = '0.1.2'
  class TypeError < StandardError; end
  module ShiftAge
    DAILY = 1
    WEEKLY = 2
    MONTHLY = 3
  end

  class Evernote
    @@note_store = nil
    
    def initialize(auth_token, is_sandbox = false)
      if @@note_store.nil?
        @@auth_token = auth_token
        @@note_store = EvernoteOAuth::Client.new({
          :token => auth_token,
          :sandbox => is_sandbox
        }).note_store
      end
    end

    # get registered notebook or create new notebook
    # search the notebook under the stack if stack_name specific
    def notebook
      Notebook.new
    end

    # get registered note or create new note
    def note(notebook)
      Note.new(notebook)
    end

    def tag(note)
      Tag.new(note)
    end

    # encode for evernote internal charset
    def to_ascii(str)
      str.force_encoding("ASCII-8BIT") unless str.nil?
    end
  end

  class Notebook < Evernote
    def initialize; end
    
    # get notebook
    def get(notebook_name, stack_name = nil)
      # return cache if same notebook and stack
      return @notebook if @notebook_name == notebook_name && @stack_name == stack_name
      # get notebook list from evernote
      @notebooks = @@note_store.listNotebooks(@@auth_token) if @notebooks.nil?
      @notebook = nil 
      @notebook_name = notebook_name
      @stack_name = stack_name
      @notebooks.each do |notebook|
        notebook_name = to_ascii(notebook_name)
        stack_name = to_ascii(stack_name)
        if notebook.name == notebook_name && notebook.stack == stack_name
          Log4r::Logger.log_internal { "Get notebook: #{stack_name}/#{notebook_name}" }
          @notebook = notebook
          break
        end
      end
      # create new notebook if notebook is nil
      create(notebook_name, stack_name) if @notebook.nil?
      @notebook
    end

    # get newest notebook
    def get!(notebook_name, stack_name = nil)
      clear
      get(notebook_name, stack_name)
    end
    
    # create notebook
    def create(notebook_name, stack_name = nil)
      notebook = ::Evernote::EDAM::Type::Notebook.new
      notebook.name = notebook_name
      notebook.stack = stack_name
      begin
        @notebook = @@note_store.createNotebook(@@auth_token, notebook)
        Log4r::Logger.log_internal { "Create notebook: #{stack_name}/#{notebook_name}" }
        @notebook
      rescue => e
        Log4r::Logger.log_internal { e.message }
        nil
      end
    end
  
    # notebook guid
    def guid; @notebook.guid end

    # clear notebook object
    def clear
      @notebooks = @@note_store.listNotebooks(@@auth_token)
      @notebook = nil
    end
  end

  class Note < Evernote
    XML_TEMPLATE_BYTE = 237
    
    def initialize(notebook)
      return unless @params.nil? || @params.empty?
      @params = {}
      @notebook = notebook
      if !@notebook.kind_of? ::Evernote::EDAM::Type::Notebook
        raise TypeError, "Expected kind of Notebook, got #{@notebook.class}", caller
      elsif !@notebook.respond_to? 'guid'
        raise NoMethodError, "#{@notebook.class} do not has method: guid", caller
      end
    end
    
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

    # get tag's guid list
    def tags
      get.tagGuids
    end

    # set tags
    def tags=(tagGuids)
      @params[:tagGuids] = tagGuids
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
    
    # get latest note object
    def get
      return @note unless @note.nil?
      filter = ::Evernote::EDAM::NoteStore::NoteFilter.new
      filter.order = ::Evernote::EDAM::Type::NoteSortOrder::CREATED
      filter.notebookGuid = @notebook.guid
      filter.timeZone = "Asia/Tokyo"
      filter.ascending = false # descending
      note_list = @@note_store.findNotes(@@auth_token, filter, 0, 1)
      if note_list.notes.empty?
        Log4r::Logger.log_internal { "Note not found at #{@notebook.guid}" }
        @note = ::Evernote::EDAM::Type::Note.new
      else  
        @note = note_list.notes[0]
      end
      @note
    end

    # get latest note object(newest object)
    def get!
      clear
      get
    end
    
    # create note object
    def createNote
      @note = ::Evernote::EDAM::Type::Note.new
      @note.notebookGuid = @notebook.guid
      @params.each{|method, value| @note.send("#{method.to_s}=", value)}
      @note
    end
    
    # get note object
    def updateNote
      @note.nil? and get
      @note.content = @params[:content]
      @note
    end
    
    # get created time 
    def created_at
      time = get.created.to_s
      ut = time.slice(0, time.length - 3)
      Time.at(ut.to_f)
    end
    
    # get note content text
    def content
      return @content_ unless @content_.nil?
      @note.nil? and get
      @content_ = !@note.nil? && !@note.guid.nil? ? @@note_store.getNoteContent(@@auth_token, @note.guid) : ""
    end

    # get note content xml object
    def content_xml
      return @content_xml unless @content_xml.nil?
      @content_xml = Nokogiri::XML(content)
    end

    # clear note object
    def clear
      @note = nil
    end
  end

  class Tag < Evernote
    def initialize(note)
      @note = note
    end

    # set tag list
    def names=(list)
      @list = list
      @tag_guids = nil
    end

    # get tag objects
    def get
      return if @list.nil? || @list.empty?
      return @tag_guids unless @tag_guids.nil?
      @list = [@list] unless @list.kind_of?(Array)
      @tags = @@note_store.listTags(@@auth_token) if @tags.nil?
      @tag_guids = @list.map do |tag|
        tag_obj = to_obj(tag) || create(tag)
        tag_obj.guid
      end
    end

    # get newest tag objects
    def get!
      clear
      get
    end
    
    # clear note object
    def clear
      @tags = nil
      @tag_guids = nil
    end

    private
    # create tag object
    def create(tag_name)
      tag = ::Evernote::EDAM::Type::Tag.new
      tag.name = tag_name
      tag_obj = @@note_store.createTag(@@auth_token, tag)
      Log4r::Logger.log_internal { "Create tag: #{tag_name}" }
      tag_obj
    end

    # tag name to tag object
    def to_obj(tag_name)
      tag_name = to_ascii(tag_name)
      @tags.each do |tag|
        if tag_name == tag.name
          Log4r::Logger.log_internal { "Get tag: #{tag_name}" }
          return tag
        end
      end
      nil
    end
  end
end