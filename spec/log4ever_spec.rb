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
      @params[:maxsize] = 1
      logger.outputters = evernoteOutputter
      logger.debug(log_content)
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      @notebook = @evernote.notebook
      notebook_obj = @notebook.get(@params[:notebook], @params[:stack])
      @note = @evernote.note(notebook_obj)
      write_log = @note.content_xml.children[1].children.reverse[0].text
      if /\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s.*?\[.*?\]:\s(.*)/ =~ write_log
        expect(log_content).to eq($1.strip)
      else
        expect("").to eq(nil) # absolutely failure.
      end
    end
  end

  describe 'Log4rの初期化処理(正常系)' do
    it 'パラメータのチェックでエラーが出ないこと' do
      logger.outputters = Log4r::EvernoteOutputter.new(LOGGER_NAME, @params)
      expect(logger.name).to eq(LOGGER_NAME)
    end

    it 'XMLから読み込んだパラメータのチェックでエラーが出ないこと' do
      # Log4r::Configurator.load_xml_file(@config_xml).should_not be_nil
      expect(Log4r::Configurator.load_xml_file(@config_xml)).to_not be_nil
    end
  end

  describe 'Log4rの初期化処理(異常系)' do
    it "sandboxパラメータのチェックでエラーが出ること" do
      expect {
        logger.outputters = Log4r::EvernoteOutputter.new(LOGGER_NAME, @params.merge(
          :sandbox => "aaa"
        ))
      }.to raise_error(ArgumentError)
    end

    it "auth_token必須パラメータのチェックでエラーが出ること" do
      expect {
        logger.outputters = Log4r::EvernoteOutputter.new(LOGGER_NAME, @params.merge(
          :auth_token => nil
        ))
      }.to raise_error(ArgumentError)
    end

    it "notebook必須パラメータのチェックでエラーが出ること" do
      expect {
        logger.outputters = Log4r::EvernoteOutputter.new(LOGGER_NAME, @params.merge(
          :notebook => nil
        ))
      }.to raise_error(ArgumentError)
    end

    it "ログローテートサイズパラメータのチェックでエラーが出ること" do
      expect {
        logger.outputters = Log4r::EvernoteOutputter.new(LOGGER_NAME, @params.merge(
          :maxsize => 0
        ))
      }.to raise_error(TypeError)
    end

    it "ログローテート期間パラメータのチェックでエラーが出ること" do
      expect {
        logger.outputters = Log4r::EvernoteOutputter.new(LOGGER_NAME, @params.merge(
          :shift_age => 4
        ))
      }.to raise_error(TypeError)
    end
  end

  describe 'Log4everの内部の処理' do
    it 'ノートブックが存在しない場合、ノートブックが新規作成されること' do
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      notebook_name = Time.now.to_i.to_s
      notebook = @evernote.notebook
      obj = notebook.get(notebook_name, @params[:stack])
      expect(obj.name).to eq(notebook_name)
    end

    it 'ノートブックが存在しない場合、スタックが新規作成されること' do
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      notebook_name = Time.now.to_i.to_s
      notebook = @evernote.notebook
      obj = notebook.get(notebook_name, @params[:stack])
      expect(obj.stack).to eq(@params[:stack])
    end

    it '指定したスタックオブジェクト(存在するスタック)を渡した場合、既存のスタックに属するノートブックが取得できること' do
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      @notebook = @evernote.notebook
      notebook_obj = @notebook.get(@params[:notebook], @params[:stack])
      expect(notebook_obj.guid).to_not be_nil
    end

    it '指定したスタックオブジェクト(存在しないスタック)を渡した場合、スタックが新規作成されノートブックが取得できること' do
      @evernote = Log4ever::Evernote.new(@params[:auth_token])
      @notebook = @evernote.notebook
      notebook_name = Time.now.to_i.to_s
      stack_name = Time.now.to_i.to_s
      notebook_obj = @notebook.get(notebook_name, stack_name)
      expect(notebook_obj.guid).to_not be_nil
    end

    it '存在するノートブックと同名のノートブックは作成できないこと' do
      expect {
        @evernote = Log4ever::Evernote.new(@params[:auth_token])
        @notebook = @evernote.notebook
        @notebook.create(@params[:notebook], @params[:stack])
      }.to raise_error(StandardError)
    end

    it 'ノートブックの取得に失敗しかつ存在するノートブックと同名のノートブックが指定された場合、作成できないこと' do
      expect {
        @evernote = Log4ever::Evernote.new(@params[:auth_token])
        @notebook = @evernote.notebook
        stack_name = Time.now.to_i.to_s
        notebook_obj = @notebook.create(@params[:notebook], stack_name)
        notebook_obj.should be_nil
      }.to raise_error(StandardError)
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
      expect(note.get.tagGuids[0]).to_not be_empty
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

      expect(guid_before).to_not eq(guid_after)
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

      expect(guid_before).to_not eq(guid_after)
    end

    it '期間単位でのログローテートを有効にしたとき、エラーが発生しないこと' do
      expect {
        logger = Log4r::Logger.new(LOGGER_NAME)
        @params.delete(:maxsize)
        @params[:shift_age] = Log4ever::ShiftAge::DAILY
        evernoteOutputter = Log4r::EvernoteOutputter.new('evernote', @params)
        logger.outputters = evernoteOutputter
        logger.info("test1")
      }.to_not raise_error
    end

    it 'スタックにUTF-8以外の文字列を指定した時、エラーが発生しないこと' do
      expect {
        @params[:stack] = "\xA4\xA2\xA4\xA2\xA4\xA2"
        @params[:notebook] = Time.now.to_i.to_s
        logger.outputters = Log4r::EvernoteOutputter.new('evernote', @params)
        logger.debug("test")
      }.to_not raise_error
    end

    it 'ノートブックにUTF-8以外の文字列を指定した時、エラーが発生しないこと' do
      expect {
        @params[:notebook] = "\xA4\xA2" + Time.now.to_i.to_s
        logger.outputters = Log4r::EvernoteOutputter.new('evernote', @params)
        logger.debug("test")
      }.to_not raise_error
    end

    it 'タグにUTF-8以外の文字列を指定した時、エラーが発生しないこと' do
      expect {
        @params[:tags] = ['Log', "\x82\xA0\x82\xA0", "\xA4\xA2"]
        logger.outputters = Log4r::EvernoteOutputter.new('evernote', @params)
        logger.debug("test")
      }.to_not raise_error
    end

    it 'ノートにUTF-8以外の文字列を指定した時、エラーが発生しないこと' do
      expect {
        logger = Log4r::Logger.new(LOGGER_NAME)
        logger.outputters = Log4r::EvernoteOutputter.new('evernote', @params)
        logger.debug("\x82\xA0") # Shift_JIS
        logger.debug("\xA4\xA2") # EUC-JP
      }.to_not raise_error
    end
  end
end
