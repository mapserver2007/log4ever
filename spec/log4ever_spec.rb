# -*- coding: utf-8 -*-
$: << File.dirname(__FILE__) + "/../lib"
require 'log4r'
require 'log4r/evernote'
require 'log4r/configurator'
require File.expand_path(File.dirname(__FILE__) + '/../spec/spec_helper')

describe Log4ever, 'が実行する処理' do
  LOGGER_NAME = 'Log4ever'
  
  before do
    @formatter = Log4r::PatternFormatter.new(
      :pattern => "%d %C[%l]: %M ",
      :date_format => "%Y/%m/%d %H:%M:%Sm"
    )
    @params = {
      :sandbox => false,
      :auth_token => Log4ever::evernote_auth,
      :stack => "Log4ever",
      :notebook => "DevelopmentLog",
      :tags => ['Log'],
      :maxsize => 500,
      #:shift_age => Log4ever::ShiftAge::DAILY,
      :formatter => @formatter
    }
  end

  let(:logger) {Log4r::Logger.new(LOGGER_NAME)}
  let(:evernoteOutputter) {
    Log4r::EvernoteOutputter.new('evernote', @params)
  }

  before do
    @config_xml = Log4ever::config_xml
  end

  describe 'Log4rのEvernote書き出し処理' do
    it '書き出しが成功すること' do
      log_content = "aaa"
      formatter_content = "\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s.*?\[.*?\]:\s(.*)\\n"
      @params[:maxsize] = 1
      logger.outputters = evernoteOutputter
      logger.debug(log_content)
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      @notebook = @evernote.notebook
      notebook_obj = @notebook.get(@params[:notebook], @params[:stack])
      @note = @evernote.note(notebook_obj)
      write_log = @note.content_xml.children[1].children.reverse[0].text
      if /\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s.*?\[.*?\]:\s(.*)/ =~ write_log
        log_content.should == $1.strip
      else
        "".should be_nil
      end
    end
  end
  
  describe 'Log4rの初期化処理(正常系)' do
    it 'パラメータのチェックでエラーが出ないこと' do
      logger.outputters = Log4r::EvernoteOutputter.new(LOGGER_NAME, @params)
      logger.name.should == LOGGER_NAME
    end

    it 'XMLから読み込んだパラメータのチェックでエラーが出ないこと' do
      Log4r::Configurator.load_xml_file(@config_xml).should_not be_nil
    end
  end

  describe 'Log4rの初期化処理(異常系)' do
    it "sandboxパラメータのチェックでエラーが出ること" do
      proc {
        logger.outputters = Log4r::EvernoteOutputter.new(LOGGER_NAME, @params.merge(
          :sandbox => "aaa"
        ))
      }.should raise_error(ArgumentError)
    end

    it "auth_token必須パラメータのチェックでエラーが出ること" do
      proc {
        logger.outputters = Log4r::EvernoteOutputter.new(LOGGER_NAME, @params.merge(
          :auth_token => nil
        ))
      }.should raise_error(ArgumentError)
    end

    it "notebook必須パラメータのチェックでエラーが出ること" do
      proc {
        logger.outputters = Log4r::EvernoteOutputter.new(LOGGER_NAME, @params.merge(
          :notebook => nil
        ))
      }.should raise_error(ArgumentError)
    end
  end

  describe 'Log4everの内部の処理' do
    it 'ノートブックが存在しない場合、ノートブックが新規作成されること' do
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      notebook_name = Time.now.to_i.to_s
      notebook = @evernote.notebook
      obj = notebook.get(notebook_name, @params[:stack])
      obj.name.should == notebook_name
    end

    it 'ノートブックが存在しない場合、スタックが新規作成されること' do
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      notebook_name = Time.now.to_i.to_s
      notebook = @evernote.notebook
      obj = notebook.get(notebook_name, @params[:stack])
      obj.stack.should == @params[:stack]
    end

    it '指定したスタックオブジェクト(存在するスタック)を渡した場合、既存のスタックに属するノートブックが取得できること' do
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      @notebook = @evernote.notebook
      notebook_obj = @notebook.get(@params[:notebook], @params[:stack])
      notebook_obj.guid.should_not be_nil
    end

    it '指定したスタックオブジェクト(存在しないスタック)を渡した場合、スタックが新規作成されノートブックが取得できること' do
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      @notebook = @evernote.notebook
      notebook_name = Time.now.to_i.to_s
      stack_name = Time.now.to_i.to_s
      notebook_obj = @notebook.get(notebook_name, stack_name)
      notebook_obj.guid.should_not be_nil
    end

    it '存在するノートブックと同名のノートブックは作成できないこと' do
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      @notebook = @evernote.notebook
      notebook_obj = @notebook.create(@params[:notebook], @params[:stack])
      notebook_obj.should be_nil
    end

    it 'ノートブックの取得に失敗しかつ存在するノートブックと同名のノートブックが指定された場合、作成できないこと' do
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      @notebook = @evernote.notebook
      stack_name = Time.now.to_i.to_s
      notebook_obj = @notebook.create(@params[:notebook], stack_name)
      notebook_obj.should be_nil
    end
  end
  
  describe 'Log4everの処理' do
    it 'タグが存在しない場合、新規作成されること' do
      @params[:tags] = [Time.now.to_i.to_s]
      @params[:maxsize] = 1
      logger.outputters = Log4r::EvernoteOutputter.new('evernote', @params)
      logger.debug("test")
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      notebook = @evernote.notebook
      note = @evernote.note(notebook.get(@params[:notebook], @params[:stack]))
      note.get.tagGuids[0].should_not be_empty
    end

    it '更新対象のノートのタグが増えた場合、新規ノートが作成されること' do
      logger = Log4r::Logger.new(LOGGER_NAME)
      # タグ変更前
      evernoteOutputter = Log4r::EvernoteOutputter.new('evernote', @params)
      logger.outputters = evernoteOutputter
      logger.info("test1")
      evernote = Log4ever::Evernote.new(@params[:auth_token])
      notebook = evernote.notebook
      note = evernote.note(notebook.get(@params[:notebook], @params[:stack])).get
      guid_before = note.guid
      # タグ変更後
      @params[:tags] << 'Log2'
      evernoteOutputter = Log4r::EvernoteOutputter.new('evernote', @params)
      logger.outputters = evernoteOutputter
      logger.info("test1")
      evernote = Log4ever::Evernote.new(@params[:auth_token])
      notebook = evernote.notebook
      note = evernote.note(notebook.get(@params[:notebook], @params[:stack])).get
      guid_after = note.guid

      guid_before.should_not == guid_after
    end

    it '更新対象のノートのタグが減った場合、新規ノートが作成されること' do
      logger = Log4r::Logger.new(LOGGER_NAME)
      # タグ変更前
      @params[:tags] << 'Log2'
      evernoteOutputter = Log4r::EvernoteOutputter.new('evernote', @params)
      logger.outputters = evernoteOutputter
      logger.info("test1")
      evernote = Log4ever::Evernote.new(@params[:auth_token])
      notebook = evernote.notebook
      note = evernote.note(notebook.get(@params[:notebook], @params[:stack])).get
      guid_before = note.guid
      # タグ変更後
      @params[:tags] = 'Log'
      evernoteOutputter = Log4r::EvernoteOutputter.new('evernote', @params)
      logger.outputters = evernoteOutputter
      logger.info("test1")
      evernote = Log4ever::Evernote.new(@params[:auth_token])
      notebook = evernote.notebook
      note = evernote.note(notebook.get(@params[:notebook], @params[:stack])).get
      guid_after = note.guid

      guid_before.should_not == guid_after
    end

    it '期間単位でのログローテートを有効にしたとき、エラーが発生しないこと' do
      proc {
        logger = Log4r::Logger.new(LOGGER_NAME)
        @params.delete(:maxsize)
        @params[:shift_age] = Log4ever::ShiftAge::DAILY
        evernoteOutputter = Log4r::EvernoteOutputter.new('evernote', @params)
        logger.outputters = evernoteOutputter
        logger.info("test1")
      }.should_not raise_error()
    end

  end
end