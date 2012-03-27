var
  fs     = require('fs')
  events = require('events'),
  clone = function (obj) {
    if(obj == null || typeof(obj) != 'object')
      return obj;
    var temp = obj.constructor(); // changed
    for(var key in obj)
      temp[key] = clone(obj[key]);
    return temp;
  };


var StreamLogger = exports.StreamLogger = function() {
  this.filePaths = [];
  for (var i = arguments.length; i != 0; i--)
    this.filePaths.push(arguments[i - 1]);
  this.fstreams  = [];
  this.emitter   = new events.EventEmitter();
  this.levels = {debug: 0, info:1, warn:2, fatal:3};
  this.level  = this.levels.info;
     
  this.open();
};

StreamLogger.prototype.__defineGetter__("levels", function() {
  return clone(this.levelList);
});
StreamLogger.prototype.__defineSetter__("levels", function(newLevels) {
  this.levelList = this.levelList || {};
   
  //Make sure the level name doesn't conflict with an existing function name
  for(var newLevel in newLevels) {
    if (this[newLevel] && (this.levelList[newLevel] == undefined)) {
      this.emitter.emit("error", "Invalid log level '" + newLevel + "', conflicting name");
      delete(newLevels[newLevel]);
    }
  }
   
  this.levelList = newLevels;

  //Build a reverse mapping of level values to keys, for fast lookup later
  this.revLevels  = {}
  for (var lName in this.levelList) {
    var lVal = this.levels[lName];
    this.revLevels[lVal]= lName; 
  }
  
  //Remove old levels
  for (var oldLevel in this.levelList)
      delete(this[oldLevel]);
   
  //Setup a method for each log level
  for (var logLevel in this.levelList) {
    this[logLevel] = (function(logLevel) {
      return function (message,callback) {
        this.logAtLevel(message, this.levelList[logLevel], callback);
      }
    })(logLevel);
  }
});

//Create write streams for all the files, emit 'open', if/when
//all streams open. Will fire callback after as well
StreamLogger.prototype.open = function(callback) {
  var emitter = this.emitter;
  for (var i = this.filePaths.length; i != 0; i--) {
    var filePath = this.filePaths[i - 1];
    var unopenedFilePathCount = this.filePaths.length;
    var stream = fs.createWriteStream(filePath, 
        {flags: 'a', mode: 0644, encoding: 'utf8'}
      )
      .addListener('open', function(fd) {
        unopenedFilePathCount--;
        if (unopenedFilePathCount == 0) {
          emitter.emit("open");
          if (callback)
            callback();
        }
      })
      .addListener('error', function(err) {
        emitter.emit('error', err,filePath)
      });
    this.fstreams.push(stream);
  }
};

//Close all write streams, fire the callback after all streams are closed
//Also emits 'close' after all streams are closed
StreamLogger.prototype.close = function(callback) {
  var openStreamsCount = this.fstreams.length,
      emitter  = this.emitter,
      slSelf = this;
      this.emittedClose = false; //Ensures we only emit 'close' once
  for (var i = openStreamsCount; i !=0; i--) {
    this.fstreams[i - 1].end(function () {
      openStreamsCount--;
      if (openStreamsCount == 0 && ! this.emittedClose) {
        //We're done closing, so emit the callbacks, then remove the fstreams
        slSelf.fstreams = [];
         
        this.emittedClose = true; 
        emitter.emit("close");
        if (callback)
          callback();
      }
    });
  }
};

StreamLogger.prototype.reopen = function(callback) {
  var slSelf = this;
  this.close(function() {
    slSelf.open(function() {
      if (callback)
        callback();
    });
  }); 
};

StreamLogger.prototype.logAtLevel = function(message,level,callback) {
  var levelName = this.revLevels[level];
  this.emitter.emit('message', message, levelName);
  this.emitter.emit('message-' + levelName, message);
   
  if (level < this.level)
    return false 
   
  this.emitter.emit('loggedMessage', message, levelName);
  this.emitter.emit('loggedMessage-' + levelName, message);

  //Check if there's a custom formatting callback
  if (this.format)
    var outMessage = this.format(message,levelName);
  else
    var outMessage = (new Date).toUTCString() + ' - ' +
                       levelName + ': ' + message; 
  
  for (var i = this.fstreams.length; i != 0; i--) {
    var fstream = this.fstreams[i - 1];
    //Ideally we could trap the errors #write creates, I'm not sure
    //if thats possible though
    if (fstream.writable) {
      fstream.write(outMessage + "\n");
      if (callback)
        callback();
    }
    else
      this.emitter.emit('error',"Stream not writable", fstream.path);
  }
};
