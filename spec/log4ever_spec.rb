# -*- coding: utf-8 -*-
$: << File.dirname(__FILE__) + "/../lib"
require 'log4r'
require 'log4r/evernote'
require 'log4r/configurator'
require File.expand_path(File.dirname(__FILE__) + '/../spec/spec_helper')

describe Log4ever, 'が実行する処理' do
  include Log4r
  LOGGER_NAME = 'Log4ever'
  
  before do
    @formatter = PatternFormatter.new(
      :pattern => "%d %C[%l]: %M ",
      :date_format => "%Y/%m/%d %H:%M:%Sm"
    )
    @params = {
      :env => "production",
      :auth_token => Log4ever::evernote_auth,
      :stack => "Log4ever",
      :notebook => "DevelopmentLog",
      :tags => ['Log'],
      :maxsize => 500,
      #:shift_age => Log4ever::ShiftAge::DAILY,
      :formatter => @formatter
    }
  end

  let(:logger) {Logger.new(LOGGER_NAME)}
  let(:evernoteOutputter) {
    EvernoteOutputter.new('evernote', @params)
  }

  before do
    @config_xml = Log4ever::config_xml
  end

  describe 'Log4rのEvernote書き出し処理' do
    it '書き出しが成功すること' do
      log_content = "aaa"
      formatter_content = "\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\s.*?\[.*?\]:\s(.*)\\n"
      @params[:maxsize] = 1
      logger.outputters = EvernoteOutputter.new('evernote', @params)
      logger.debug(log_content)
      @evernote = MyEvernote.new(@params[:env], @params[:auth_token])
      @notebook = @evernote.get_notebook(@params[:notebook], @params[:stack])
      @note = @evernote.get_note(@notebook)
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
      logger.outputters = EvernoteOutputter.new(LOGGER_NAME, @params)
      logger.name.should == LOGGER_NAME
    end

    it 'XMLから読み込んだパラメータのチェックでエラーが出ないこと' do
      Configurator.load_xml_file(@config_xml).should_not be_nil
    end
  end

  describe 'Log4rの初期化処理(異常系)' do
    it "envパラメータのチェックでエラーが出ること" do
      proc {
        logger.outputters = EvernoteOutputter.new(LOGGER_NAME, @params.merge(
          :env => "aaa"
        ))
      }.should raise_error(ArgumentError)
    end

    it "auth_token必須パラメータのチェックでエラーが出ること" do
      proc {
        logger.outputters = EvernoteOutputter.new(LOGGER_NAME, @params.merge(
          :auth_token => nil
        ))
      }.should raise_error(ArgumentError)
    end

    it "notebook必須パラメータのチェックでエラーが出ること" do
      proc {
        logger.outputters = EvernoteOutputter.new(LOGGER_NAME, @params.merge(
          :notebook => nil
        ))
      }.should raise_error(ArgumentError)
    end
  end
  
  describe 'Log4everの処理' do
    it 'ノートブックが存在しない場合、新規作成されること' do
      logger.outputters = evernoteOutputter
      @evernote = MyEvernote.new(@params[:env], @params[:auth_token])
      notebook_name = Time.now.to_i.to_s
      notebook = @evernote.get_notebook(notebook_name, @params[:stack])
      obj = notebook.get(notebook_name, @params[:stack])
      obj.name.should == notebook_name
      obj.stack.should == @params[:stack]
    end
  
    it 'タグが存在しない場合、新規作成されること' do
      @params[:tags] = [Time.now.to_i.to_s]
      @params[:maxsize] = 1
      logger.outputters = EvernoteOutputter.new('evernote', @params)
      logger.debug("test")
      evernote = MyEvernote.new(@params[:env], @params[:auth_token])
      notebook = evernote.get_notebook(@params[:notebook], @params[:stack])
      note = evernote.get_note(notebook)
      note.getNoteObject.tagGuids[0].should_not be_empty
    end
  end
end