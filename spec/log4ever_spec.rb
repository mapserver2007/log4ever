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
      @evernote = Log4ever::Evernote.new(@params[:env], @params[:auth_token])
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
    it "envパラメータのチェックでエラーが出ること" do
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
    it '指定したスタック名が存在する場合、スタックが取得できること' do

    end

    it '指定したスタック名が存在しない場合、スタックは取得できないこと' do

    end

    it '指定したスタックオブジェクト(存在するスタック)を渡した場合、スタックに属するノートブックが取得できること' do

    end

    it '指定したスタックオブジェクト(存在しないスタック)を渡した場合、ノートブックが取得できないこと' do

    end

    it 'スタックオブジェクトを渡さない場合、全てのノートブックが取得できること' do

    end

    it '指定したノートブックオブジェクト(存在するノートブック)を渡した場合、ノートブックに属するノートが取得できること' do

    end

    it '指定したノートブックオブジェクト(存在しないノートブック)を渡した場合、ノートが取得できないこと' do

    end

    it 'ノートブックオブジェクトを渡さない場合、全てのノートが取得できること' do

    end

  end


  
  describe 'Log4everの処理' do
    it 'ノートブックが存在しない場合、ノートブックが新規作成されること' do
      logger.outputters = evernoteOutputter
      @evernote = Log4ever::Evernote.new(@params[:env], @params[:auth_token])
      notebook_name = Time.now.to_i.to_s
      notebook = @evernote.notebook
      obj = notebook.get(notebook_name, @params[:stack])
      obj.name.should == notebook_name
    end

    it 'ノートブックが存在しない場合、スタックが新規作成されること' do
      logger.outputters = evernoteOutputter
      @evernote = Log4ever::Evernote.new(@params[:env], @params[:auth_token])
      notebook_name = Time.now.to_i.to_s
      notebook = @evernote.notebook
      obj = notebook.get(notebook_name, @params[:stack])
      obj.stack.should == @params[:stack]
    end
  
    it 'タグが存在しない場合、新規作成されること' do
      @params[:tags] = [Time.now.to_i.to_s]
      @params[:maxsize] = 1
      logger.outputters = Log4r::EvernoteOutputter.new('evernote', @params)
      logger.debug("test")
      @evernote = Log4ever::Evernote.new(@params[:env], @params[:auth_token])
      notebook = @evernote.notebook
      note = @evernote.note(notebook.get(@params[:notebook], @params[:stack]))
      note.get.tagGuids[0].should_not be_empty
    end

    it 'スタックが存在しない場合かつノートブックが存在しない場合、スタックとノートブックが新規作成されること' do

    end

    it 'スタックが存在する場合、既存のスタック配下にノートブックが新規作成されること' do

    end

    it 'スタックとノートブックが存在する場合かつローテート対象でなくタグが一致するノートが存在する場合、既存のノートに追記されること' do

    end

    it 'スタックとノートブックが存在する場合かつローテート対象でなくタグが一致するノートが存在しない場合、新規ノートが作成されること' do

    end





  end
end