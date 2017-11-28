JSON = require("JSON")
exitflag = false;

function has_value (tab, val)
    for index, value in ipairs (tab) do
        if (value == val) then
            return true;
        end
    end
    return false;
end

function parseJson(resp)
 local  message = JSON:decode(resp);

  if(message["status"] == "success") then
      if(message.data[1].cmd == "justdial") then
         exitflag = true;
            caller_id = session:getVariable("effective_caller_id_number");
            session:setVariable("effective_caller_id_name", caller_id);
      --      if(caller_id == nil) then
               caller_id = message.data[1].options.caller_id;
               session:setVariable("effective_caller_id_number", caller_id);
               session:setVariable("effective_caller_id_name", caller_id);
        --    end

         if(type(message.data[1].options.to) == "table" ) then
            call_timeout = message.data[1].options.ring_time;
             if(call_timeout == nil) then
                call_timeout = 20;
             end
           session:execute("set", "execute_on_answer=sched_hangup +3600 alloted_timeout");
           session:execute("set", "transfer_ringback=$${us-ring}");
           session:execute("set", "call_timeout="..call_timeout);
           session:setVariable("to_number", message.data[1].options.to.internal);
           session:execute("set", "origination_cancel_key=#");
           session:execute("set", "continue_on_fail=1,3,17,18,19,21,27,41,606");
           session:execute("set", "hangup_after_bridge=true");
           -- freeswitch not to send updates to leg A. For leg B, it will be added to bridge
           session:execute("set", "ignore_display_updates=true");
           session:execute("bridge_export", "hold_music=$${sounds_dir}/en/us/callie/misc/8000/010.wav");
           session:execute("bridge", "{ignore_display_updates=true}"..internal_dialstring);
            if(session:ready() == true) then
                local obCause = session:hangupCause()
                session:execute("lua", "voicemail.lua "..JSON:encode(message));
            end 
         else
           -- calls to external party using bandwidth.
          local dialstring =  "sofia/gateway/bandwidth/"..message.data[1].options.to;
          session:execute("set", "hangup_after_bridge=true");
          session:execute("bridge", dialstring);
         end
      elseif(message.data[1].cmd == "forwardcall") then
           from_type = message.data[1].options.from_type;
           session:setVariable("accountcode", message.data[1].options.user_id);
           if(type(message.data[1].options.to.extensions) == "table") then
                 caller_id = message.data[1].options.caller_id;
                 session:setVariable("effective_caller_id_number", caller_id);
             if(message.data[1].options.to.extensions[1] ~= nil) then
                 local extnid = message.data[1].options.to.extensions[1];
                 if(has_value(forwardcall_tolist, extnid)) then
                    session:answer();
                    session:execute("lua", "voicemail.lua "..JSON:encode(message));
                 else
                    table.insert(forwardcall_tolist, extnid);
                    if(from_type~= nil and from_type == "internal_s") then
                       local startidx = string.find(extnid, "xen");
                       if(startidx ~= nil) then
                          extnid = string.sub(extnid, startidx+3);
                       end
                    end
                    --  callXenApi(original_caller_id, extnid, from_type);
                    --  parseJson(curl_response);
--                    session:transfer(extnid,"XML", "AJR");
                    isTransferred = true;
                    session:execute("transfer", extnid.." XML AJR");
                 end
             elseif(message.data[1].options.to.internal[1] ~= nil) then
                 local to_nbr = message.data[1].options.to.internal[1];
                 if(has_value(forwardcall_tolist, to_nbr)) then
                    session:answer();
                    session:execute("lua", "voicemail.lua "..JSON:encode(message));
                 else
                    table.insert(forwardcall_tolist, to_nbr);
                   -- callXenApi(original_caller_id, to_nbr, from_type);
                   -- parseJson(curl_response);
                      isTransferred = true;
                      session:execute("transfer", to_nbr.."XML AJR");
                 end
             elseif(message.data[1].options.to.external[1] ~= nil) then
                   session:execute("set", "call_timeout=20");
                   --session:execute("set", "ignore_early_media=true");
                   session:execute("set", "continue_on_fail=1,3,17,18,19,21,27,41,606");
                   session:execute("set", "hangup_after_bridge=true");
                   dialstring =  "sofia/gateway/bandwidth/"..message.data[1].options.to.external[1];
		   session:execute("bridge", dialstring);              
                   session:answer();
                   if(session:ready() == true) then
                      session:execute("lua", "voicemail.lua "..JSON:encode(message));
                   end
             end
           end		
      elseif(message.data[1].cmd == "goto_voicemail")then
         session:answer();
         session:execute("lua", "voicemail.lua "..JSON:encode(message));
      elseif(message.data[1].cmd == "goto_menu") then
	startivrmenu(message);             
      elseif(message.data[1].cmd == "dnd") then
          session:setVariable("DIALSTATUS", "DND");
          session:execute("hangup", "SUBSCRIBER_ABSENT");
      elseif(message.data[1].cmd == "hangup") then
          session:setVariable("DIALSTATUS", "NONUMBER");
          session:execute("hangup", "NO_ROUTE_DESTINATION");
      end
  elseif(message["status"] == "error") then
    local data = message.errors[1];
    if(data.cmd == "error") then
         invalidDTMF = invalidDTMF + 1;
         session:streamFile(invalid_greeting);
         session:execute("set", "tts_engine=flite")
         session:execute("set", "tts_voice=kal");
         session:execute("speak", data.options.message);
    end    
  end
end


function callXenApi(from, to, from_type)
  if(from ~= nil and to ~= nil) then
     query_str = "from="..from.."&to="..to;
     if(from_type ~= nil) then
        query_str = query_str.."&from_type="..from_type;
     end     
     session:setVariable("curl_timeout", "5");
     session:execute("curl", xen360_url.."/api/amis/commands?"..query_str.." req-headers 'av_token:"..app_token..";user_ip:"..user_ip.."'");
     local curl_response_code = session:getVariable("curl_response_code");
     curl_response      = session:getVariable("curl_response_data");
     -- remove whitespaces if any
     curl_response = string.gsub(curl_response, "%s+", "");
     session:consoleLog("info", curl_response);
     session:consoleLog("info", curl_response_code);
     if(curl_response == nil) then
       --session:answer();
       session:execute("set", "tts_engine=flite")
       session:execute("set", "tts_voice=kal");
       session:execute("speak", "We are extremely sorry for the inconvenience. Some aplication error occurred. Please try again after some time");
       session:hangup();
     else      
        return curl_respone;
     end
  end
end


function startivrmenu(message)
  local ivrMaxAttempts = 1;
  invalidDTMF = 1;
  if(exitflag == true) then
   session:streamFile(sounds_dir.."/voicemail/8000/vm-goodbye.wav");
   session:hangup();
  else
    
    while(session:ready() == true and ivrMaxAttempts < 3) do
      ivrMaxAttempts = ivrMaxAttempts + 1;
      if(exitflag == true or invalidDTMF == 3) then 
        session:streamFile(sounds_dir.."/voicemail/8000/vm-goodbye.wav");
        session:hangup();
        return;
      end
     --session:consoleLog("err", "Attempts:"..ivrMaxAttempts);
     out_greeting = message.data[1].options.outgoing_greeting;
     invalid_greeting = message.data[1].options.invalid_greeting;
     nokey_pressed = message.data[1].options.no_key_pressed;
     if(invalid_greeting == nil) then
        invalid_greeting = sounds_dir.."/ivr/8000/InvalidMenuOption.mp3";
     end 
     extnsize = table.getn(message.data[1].options.extensions);
     max_digits = 4;
     -- maximum 3 or 4 digits are accepted for extension;
     matches_regex = "\\d{4}";
     if(extnsize == 0) then
        max_digits = 1;
        matches_regex = "["..table.concat(message.data[1].options.matches).."]";
     end
     digits = session:playAndGetDigits(1, max_digits, 1, 5000, "#", out_greeting, "", matched_regex, "digits_received", 2000, "");
     session:consoleLog("info", "digits entered:"..digits );
     from_type = message.data[1].options.from_type;
      if(digits ~= "" and string.len(digits) == 1) then
        if(has_value(message.data[1].options.matches, digits)) then 
            session:execute("curl", xen360_url.."/api/amis/commands?from="..original_caller_id.."&to="..destination.."&user_id="..message.data[1].options.user_id.."&menu_id="..message.data[1].options.menu_id.."&mo="..digits.." req-headers 'av_token:"..app_token..";user_ip:"..user_ip.."'");
      	    local curl_response_code = session:getVariable("curl_response_code")
      	    local curl_response      = session:getVariable("curl_response_data")
      	    session:consoleLog("info", curl_response);
            -- remove whitespaces if any
            curl_response = string.gsub(curl_response, "%s+", "");
      	    parseJson(curl_response);
        else 
           session:streamFile(invalid_greeting);
        end
      elseif (string.len(digits) == 3 or string.len(digits) == 4) then
         if(has_value(message.data[1].options.extensions, digits)) then
             local startidx = string.find(original_caller_id, "xen");
             if(startidx ~= nil) then
                  eff_caller_id = string.sub(original_caller_id, startidx+3);
             else
                  eff_caller_id = original_caller_id;
             end
             session:setVariable("effective_caller_id_number", eff_caller_id);
             extn = digits;
             localAcctNbr = destination;
             if(from_type ~= nil and from_type ~= "internal_s") then
                extn = message.data[1].options.user_id.."xen"..extn;
             end 
             --session:consoleLog("err", "extn:"..extn);
             session:streamFile(sounds_dir.."/ivr/8000/ivr-hold_connect_call.wav");
             callXenApi(original_caller_id, extn, from_type); 
             session:consoleLog("info", curl_response);
             parseJson(curl_response);
         else
             session:streamFile(sounds_dir.."/ivr/8000/ivr-invalid_extension_try_again.wav"); 
            -- session:execute("playback", "silence_stream://2000");
         end
      elseif(digits ~= "") then
         session:streamFile(sounds_dir.."/ivr/8000/InvalidMenuOption.mp3");
      end
      if(digits == "" and nokey_pressed ~= nil) then
        session:execute("curl", xen360_url.."/api/amis/commands?from="..original_caller_id.."&to="..destination.."&user_id="..message.data[1].options.user_id.."&menu_id="..message.data[1].options.menu_id.."&mo=-1 req-headers 'av_token:"..app_token..";user_ip:"..user_ip.."'");
            local curl_response_code = session:getVariable("curl_response_code")
            local curl_response      = session:getVariable("curl_response_data")
            session:consoleLog("info", curl_response);
            -- remove whitespaces if any
            curl_response = string.gsub(curl_response, "%s+", "");
            parseJson(curl_response);
      end
    end
    if(not isTransferred) then
       session:consoleLog("warn", "no input");
       session:execute("playback", "silence_stream://1000");
       session:streamFile(sounds_dir.."/voicemail/8000/vm-goodbye.wav");
       session:hangup();
    end
  end
end

local hex_to_char = function(x)
  return string.char(tonumber(x, 16))
end

local unescape = function(url)
  return url:gsub("%%(%x%x)", hex_to_char)
end


if(argv[1]) then
  local  msg = JSON:decode(argv[1]);
  sounds_dir = session:getVariable("sound_prefix");
  local dial_string = session:getVariable("internal_dialstring");
  internal_dialstring = unescape(dial_string);
  caller_id = session:getVariable("caller_id_number");
  original_caller_id = caller_id;
  destination = session:getVariable("destination_number");
  xen360_url = session:getVariable("xen360_url");
  app_token = session:getVariable("xen360_app_token");
  user_ip = session:getVariable("domain");
  forwardcall_tolist = {};
  table.insert(forwardcall_tolist, original_caller_id);
  startivrmenu(msg);
else 
  session:hangup();
end
