JSON = require("JSON")

function myHangupHook()
   freeswitch.consoleLog("NOTICE", "myHangupHook: "..filename);
   stop_epoch = os.time();
   duration = stop_epoch - start_epoch;
   freeswitch.consoleLog("INFO", duration);
   api = freeswitch.API();
   postParams = "asset[callerid]="..callerid.."&asset[mailboxuser]="..mailboxuser.."&asset[origtime]='"..orig_time.."'&asset[duration]="..duration.."&asset[msgnum]=0&asset[msg_id]="..uuid;
   get_response = api:execute("curl_sendfile", xen360_url.."/api/voicemails  file="..filename.." "..postParams.." event "..uuid.." 'av_token:"..app_token..";user_ip:"..user_ip.."'");
   freeswitch.consoleLog("NOTICE", "myHangupHook: get_resp:"..get_response);
   if(get_response ~= nil and string.find(get_response, "+200") ~= nil) then
      os.remove(filename);
   else
     vm_filename =  os.date('vm_%Y%m%d_%H')
     file = io.open(vm_dir.."/vmbackup/status/"..vm_filename..".txt", "a")
     file:write(callerid..','..mailboxuser..','..duration..','..uuid..','..orig_time..','..filename, "\n")
     file:close();
   end

end


if (argv[1]) then   
  message = JSON:decode(argv[1]);
  sounds_dir = session:getVariable("sound_prefix");
  vm_dir = session:getVariable("recordings_dir");
  xen360_url = session:getVariable("xen360_url");
  app_token = session:getVariable("xen360_app_token");
  user_ip = session:getVariable("domain");
  local destination = session:getVariable("destination_number");
   greetFileStatus = "0";
   mailboxuser = "";
   if(type(message.data.options) == "table" ) then
       greeting = message.data.options.greeting;
       mailboxuser = message.data.options.mailbox;
       --session:consoleLog("err", mailboxuser);
       if(mailboxuser == nil) then
           if(type(message.data.options.to) == "table" ) then
              if(type(message.data.options.to.extensions) == "table") then
                if(message.data.options.to.extensions[1] ~= nil) then
                   mailboxuser = message.data.options.to.extensions[1];
                elseif(message.data.options.to.internal[1] ~= nil) then 
                   mailboxuser = message.data.options.to.internal[1];
                elseif(message.data.options.to.external[1] ~= nil) then
                   mailboxuser = destination;
                end
              else 
                 mailboxuser = message.data.options.to.internal;
              end
           else 
                mailboxuser = message.data.options.to;
           end
       --session:consoleLog("info", mailboxuser);
       end
   end
   -- silence for 1 second.
   session:execute("playback", "silence_stream://1000");
   if(greeting == nil or greetinig == '') then 
       session:streamFile(sounds_dir.."/voicemail/8000/vm-record_greeting.wav");
       session:streamFile(sounds_dir.."/voicemail/8000/beep-01a.mp3");
      -- session:set_tts_params("flite", "kal");
      -- session:speak("Please leave your message. I will get back to as soon as possible");
   else
       -- sleep for 1 second to avoid cutting of few milliseconds of file.
       session:execute("sleep", "1000"); 
       greetFileStatus = session:streamFile(greeting);
       if(greetFileStatus == 0) then
          session:streamFile(sounds_dir.."/voicemail/8000/vm-record_greeting.wav");
       end
       session:streamFile(sounds_dir.."/voicemail/8000/beep-01a.mp3");
   end
  callerid = message.data.options.caller_id;
  uuid = session:getVariable("uuid");
  start_epoch = os.time();
  orig_time = os.date('%m/%d/%Y %H:%M:%S', start_epoch);
  created_time = os.date('%Y%m%d%H%M%S', start_epoch);
  filename = vm_dir.."/vmbackup/"..mailboxuser.."_"..callerid.."_"..created_time.."_"..uuid..".mp3";
 
  blah="w00t";
  session:setHangupHook("myHangupHook", "blah");
  -- record the VM: max time: 120sec, energy level: 400, Hangup if silence for:5 secs
  session:recordFile(filename, 120, 400, 5);
  session:setVariable("DIALSTATUS", "VOICEMAIL");
  session:streamFile(sounds_dir.."/voicemail/8000/vm-goodbye.wav");
  session:hangup();
else
  session:consoleLog("err","gone"); 
  session:hangup();
end
