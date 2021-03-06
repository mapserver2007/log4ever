# log4ever
[![Build Status](https://travis-ci.org/mapserver2007/log4ever.svg?branch=master)](https://travis-ci.org/mapserver2007/log4ever)

log4ever is simple logger for evernote. It is available as an extension of [log4r](http://log4r.rubyforge.org/).
***
### Install
```
$> gem install log4ever
```

### Usage
```ruby
# -*- coding: utf-8 -*-
require 'log4r'
require 'log4r/evernote'

logger = Log4r::Logger.new("Evernote")
logger.level = Log4r::INFO
formatter = Log4r::PatternFormatter.new(
    :pattern => "%d %C[%l]: %M ",
    :date_format => "%Y/%m/%d %H:%M:%Sm"
)
stdoutOutputter = Log4r::StdoutOutputter.new('console', {
    :formatter => formatter
})
evernoteOutputter = Log4r::EvernoteOutputter.new('evernote', {
    :sandbox => false, #  Execution environment in Evernote (true: sandbox, false: production, default: production)
    :auth_token => "xxxxxxxxxxxxxxxxxxxxxxx", # evernote auth token
    :stack => "Log4ever", # evernote stack name
    :notebook => "DevelopmentLog", # evernote notebook name
    :tags => ['Log'], # evernote tag (Can be specified in the list)
    :maxsize => 500, # Maximum size of the logs to be rotated
    #:shift_age => Log4ever::ShiftAge::DAILY, # Cycle of the logs to be rotated
    :formatter => formatter
})

logger.outputters = [stdoutOutputter, evernoteOutputter]
logger.info('log output')
```

Output:
```
2012-08-06 21:12:31 Evernote[INFO]: log output
```

The output results are stored in Evernote.

### ChangeLog
* 0.0.1
First release.
* 0.0.2
Remove unnecessary processing.
* 0.0.3
If tag, notebook does not exist, it will be created.
* 0.0.4
Add dependency gem.
* 0.0.5
Bug fix.
* 0.0.6
Bug fix.
* 0.0.7
Bug fix.
* 0.0.8
Add dependency library.
* 0.0.9
Add dependency library.
* 0.1.0
Change the parameter of EvetnoteOutputter class, use evernote_oauth.
* 0.1.1
Performance improvement.
* 0.1.2
Bug fix.
* 0.1.3
Ruby2.0.0 support. Bug fix.
* 0.1.4
Add testcase.
* 0.1.5
Performance improvement.
* 0.1.6
Ruby2.1 support.
* 0.1.7
Ruby2.2 support.
* 0.1.8
Ruby2.3 support.

## License
Licensed under the MIT
http://www.opensource.org/licenses/mit-license.php
