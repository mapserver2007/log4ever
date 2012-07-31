# -*- coding: utf-8 -*-
$: << File.dirname(__FILE__) + "/../lib"
require 'log4r'
require 'log4r/evernote'
require File.expand_path(File.dirname(__FILE__) + '/../spec/spec_helper')

describe Log4ever, 'が実行する処理' do
  include Log4r
  LOGGER_NAME = 'Log4ever'
  
  it "test" do
    logger = Logger.new("test")
    #logger.outputters = StdoutOutputter.new('console')
    logger.outputters = EvernoteOutputter.new('evernote', {
      :env => "sandbox"
    })
    logger.debug('log output')
  end
  
  let(:logger) {Logger.new(LOGGER_NAME)}
  
  describe 'Log4rの初期化処理(正常系)' do
    
    
    it 'envパラメータのチェックでエラーが出ないこと' do
      logger.outputters = EvernoteOutputter.new(LOGGER_NAME, {
        :env => "sandbox"
      })
      logger.name.should == LOGGER_NAME
    end
    
    
  end
  
  describe 'Log4rの初期化処理(異常系)' do
    it "envパラメータのチェックでエラーが出ること" do
      proc {
        logger.outputters = EvernoteOutputter.new(LOGGER_NAME, {
          :env => "aaa"
        })
      }.should raise_error(ArgumentError)
      
    end
  end
  
  
  
  
end