#log4ever
log4ever is simple logger for evernote. It is available as an extension of [log4r]http://log4r.rubyforge.org/).
***
###Usage

    logger = Logger.new("Evernote")
    logger.outputters = StdoutOutputter.new('console')
    formatter = PatternFormatter.new(
        :pattern => "%d %C[%l]: %M ",
        :date_format => "%Y/%m/%d %H:%M:%Sm"
    )
    stdoutOutputter = StdoutOutputter.new('console', {
        :formatter => formatter
    })
    evernoteOutputter = EvernoteOutputter.new('evernote', {
        :env => "production", # Execution environment in Evernote (production or sandbox) 
        :auth_token => "xxxxxxxxxxxxxxxxxxxxxxx" # evernote auth token
        :stack => "Log4ever", # evernote stack name
        :notebook => "DevelopmentLog", # evernote notebook name
        :tags => ['Log'], # evernote tag (Can be specified in the list)
        :maxsize => 500, # Maximum size of the logs to be rotated
        #:shift_age => Log4ever::ShiftAge::DAILY, # Cycle of the logs to be rotated
        :formatter => formatter
    })

    logger.outputters = [stdoutOutputter, evernoteOutputter]
    logger.info('log output')
Output:
    2012-08-06 21:12:31 Evernote[INFO]: log output

##License
Licensed under the MIT
http://www.opensource.org/licenses/mit-license.php