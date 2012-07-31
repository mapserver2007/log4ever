# -*- coding: utf-8 -*-

module Log4r
  class EvernoteOutputter < Outputter
    
    def initialize(_name, hash={})
      super(_name, hash)
      validate(hash)
      
      
    end
    
    def validate(hash)
      # TODO ここでノートブック名とかチェック？
      # ハッシュには認証情報とかノートとか
    end
    
    def canonical_log(logevent)
      p logevent
      super(logevent)
      # TODO ここでEvernote送信処理？
      
    end
    
    
    

    
  end
end