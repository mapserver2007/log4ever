# -*- coding: utf-8 -*-
require 'log4r/outputter/evernoteoutputter'
require 'evernote_oauth'

module Log4ever
  VERSION = '0.1.5'

  class EvernoteError < StandardError; end

  module ShiftAge
    DAILY = 1
    WEEKLY = 2
    MONTHLY = 3
  end

  class EvernoteAuth
    attr_reader :auth_token
    attr_reader :note_store

    def initialize(auth_token, is_sandbox = false)
      @auth_token = auth_token
      @note_store = EvernoteOAuth::Client.new({
        :token => auth_token,
        :sandbox => is_sandbox
      }).note_store
    end
  end

  class Evernote
    @@auth_store = nil

    # Execute authentication to evernote
    def initialize(auth_token, is_sandbox = false)
      if @@auth_store.nil?
        @@auth_store = EvernoteAuth.new(auth_token, is_sandbox)
      end
    end

    # get registered notebook or create new notebook
    # search the notebook under the stack if stack_name specific
    def notebook
      @notebook = Notebook.new(@@auth_store) if @notebook.nil?
      @notebook
    end

    # get registered note or create new note
    def note(notebook)
      @note = Note.new(notebook, @@auth_store) if @note.nil?
      @note
    end

    # get registered tag or create new tag
    def tag(note)
      @tag = Tag.new(note, @@auth_store) if @tag.nil?
      @tag
    end
  end

  class Notebook
    # constructor
    def initialize(auth_store)
      @auth_store = auth_store
    end

    # get notebook
    def get(notebook_name, stack_name = nil)
      # return cache if same notebook and stack
      return @notebook if @notebook_name == notebook_name && @stack_name == stack_name
      # get notebook list from evernote
      @notebooks = @auth_store.note_store.listNotebooks(@auth_store.auth_token) if @notebooks.nil?
      @notebook = nil
      @notebook_name = notebook_name
      @stack_name = stack_name
      @notebooks.each do |notebook|
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
        @notebook = @auth_store.note_store.createNotebook(@auth_store.auth_token, notebook)
        Log4r::Logger.log_internal { "Create notebook: #{stack_name}/#{notebook_name}" }
        @notebook
      rescue => e
        Log4r::Logger.log_internal { e.message }
        raise EvernoteError, "Create notebook failed. Probably, already exists notebook of same name.", caller if @notebook.nil?
      end
    end

    # notebook guid
    def guid; @notebook.guid end

    # clear notebook object
    def clear
      @notebooks = @auth_store.note_store.listNotebooks(@auth_store.auth_token)
      @notebook = nil
    end
  end

  class Note
    XML_TEMPLATE_BYTE = 237

    def initialize(notebook, auth_store)
      return unless @params.nil? || @params.empty?
      @params = {}
      if !notebook.kind_of? ::Evernote::EDAM::Type::Notebook
        raise EvernoteError, "Expected kind of Notebook, got #{notebook.class}", caller
      elsif !notebook.respond_to? 'guid'
        raise NoMethodError, "#{notebook.class} do not has method: guid", caller
      end
      @notebook = notebook
      @auth_store = auth_store
    end

    # content size
    def size
      content.bytesize > 0 ? content.bytesize - XML_TEMPLATE_BYTE : 0
    end

    # note guid
    def guid; @note.guid end

    # set new title
    def title=(str)
      @params[:title] = str
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
      new_html = "<div style='font-family: Courier New'>" + text + "</div>"
      content_xml.at('en-note').inner_html += new_html
      @params[:content] = @content_ = content_xml.to_xml
    end

    # set new content
    def content=(text)
      @params[:content] = @content_ = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n" +
      "<!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\">\n" +
      "<en-note style=\"word-wrap: break-word; -webkit-nbsp-mode: space; -webkit-line-break: after-white-space;\">\n" +
      "<div style=\"font-family: Courier New\">" + text + "</div></en-note>"
    end

    # get note content text
    def content
      return @content_ unless @content_.nil?
      @note.nil? and get
      @content_ = !@note.nil? && !@note.guid.nil? ? @auth_store.note_store.getNoteContent(@auth_store.auth_token, @note.guid) : ""
    end

    # get note content xml object
    def content_xml
      return @content_xml unless @content_xml.nil?
      @content_xml = Nokogiri::XML(content)
    end

    # create note
    def create
      @auth_store.note_store.createNote(@auth_store.auth_token, createNote)
      @note = nil
    end

    # update note
    def update
      @auth_store.note_store.updateNote(@auth_store.auth_token, updateNote)
    end

    # get latest note object
    def get
      return @note unless @note.nil?
      filter = ::Evernote::EDAM::NoteStore::NoteFilter.new
      filter.order = ::Evernote::EDAM::Type::NoteSortOrder::CREATED
      filter.notebookGuid = @notebook.guid
      filter.timeZone = "Asia/Tokyo"
      filter.ascending = false # descending
      note_list = @auth_store.note_store.findNotes(@auth_store.auth_token, filter, 0, 1)
      if note_list.notes.empty?
        Log4r::Logger.log_internal { "Note not found at #{@notebook.guid}" }
        @note = ::Evernote::EDAM::Type::Note.new
      else
        @note = note_list.notes[0]
      end
      @note
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
  end

  class Tag
    def initialize(note, auth_store)
      @note = note
      @auth_store = auth_store
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
      @tags = @auth_store.note_store.listTags(@auth_store.auth_token) if @tags.nil?
      @tag_guids = @list.map do |tag|
        tag_obj = to_obj(tag) || create(tag)
        tag_obj.guid
      end
    end

    private
    # create tag object
    def create(tag_name)
      tag = ::Evernote::EDAM::Type::Tag.new
      tag.name = tag_name
      tag_obj = @auth_store.note_store.createTag(@auth_store.auth_token, tag)
      Log4r::Logger.log_internal { "Create tag: #{tag_name}" }
      tag_obj
    end

    # tag name to tag object
    def to_obj(tag_name)
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