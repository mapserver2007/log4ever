# -*- coding: utf-8 -*-
$: << File.dirname(__FILE__) + "/../lib"
require 'log4r'
require 'log4r/evernote'
require 'log4r/configurator'
require File.expand_path(File.dirname(__FILE__) + '/../spec/spec_helper')

describe Log4ever, 'が実行する処理' do
  include Log4r
  LOGGER_NAME = 'Log4ever'

  it "normal" do
    logger = Logger.new("test")
    #logger.outputters = StdoutOutputter.new('console')

    formatter = PatternFormatter.new(
      :pattern => "%d %C[%l]: %M ",
      :date_format => "%Y/%m/%d %H:%M:%Sm"
    )

    logger.outputters = [EvernoteOutputter.new('evernote', {
      :env => "production",
      :auth_token => "xxxxxxx",
      :stack => "Log4ever",
      :notebook => "DevelopmentLog",
      :tags => ['Log'],
      :formatter => formatter
    })]
    logger.debug('log output')
    #logger.debug('にほんごー')
    #logger.debug('アッカリーン')
    #logger.debug('ｱｯｶﾘｰﾝ')
    #logger.debug('ｷﾀ━━━━(ﾟ∀ﾟ)━━━━!!')
  end

  it "from file" do
    #Configurator.load_xml_file(Log4ever::config_xml)
    #logger = Logger.get('test')
    #logger.debug('log output')
  end

  let(:logger) {Logger.new(LOGGER_NAME)}

  before do
    @params = {
      :env => "sandbox",
      :auth_token => "xxxxxxxxxxxxxxxxxx",
      :notebook => "Notebook",
      :stack => nil
    }
    @config_xml = Log4ever::config_xml
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


end