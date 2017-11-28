JSON = require("JSON");

function has_value (tab, val)
    for index, value in ipairs (tab) do
        if (value == val) then
            return true;
        end
    end
    return false;
end

function parseJson(resp)
  message = JSON:decode(resp);
  if(message["status"] == "success") then
      if(message.data.cmd == "justdial") then
            caller_id = session:getVariable("effective_caller_id_number");
            session:setVariable("effective_caller_id_name", caller_id);
            session:setVariable("accountcode", message.data.options.user_id);
            if(nil ~= message.data.plan) then
               session:setVariable("xen_plan", JSON:encode(message.data.plan));
            end
            local plan = JSON:encode(message.data.plan);
session:consoleLog("err","####PLAN")
session:consoleLog("err", plan);
            if(caller_id == nil) then 
               caller_id = message.data.options.caller_id;
               session:setVariable("effective_caller_id_number", caller_id);
               session:setVariable("effective_caller_id_name", caller_id);
            end
         if(type(message.data.options.to) == "table" ) then 
             call_timeout = message.data.options.ring_time;
             if(call_timeout == nil) then
                call_timeout = 20;
             end
             if(message.data.options.from == message.data.options.to.internal) then
                session:answer();
                session:execute("lua", "voicemail.lua "..JSON:encode(message));
                return;
             end  
             session:execute("set", "execute_on_answer=sched_hangup +3600 alloted_timeout");
             session:setVariable("to_number", message.data.options.to.internal);          
             --session:execute("export", "call_timeout="..call_timeout);
             session:execute("export", "leg_timeout="..call_timeout);
             session:execute("set", "transfer_ringback=$${us-ring}");
             session:execute("set", "ringback=$${us-ring}");
             -- check Q.850 codes
             -- UNALLOCATED_NUMBER,USER_BUSY,NO_USER_RESPONSE,NO_ANSWER,NO_ROUTE_DESTINATION,CALL_REJECTED");
             session:execute("set", "continue_on_fail=1,3,17,18,19,21,27,41,606,602");
             session:execute("set", "hangup_after_bridge=true");
             session:execute("bridge_export", "hold_music=$${sounds_dir}/en/us/callie/misc/8000/010.wav");
            --  session:execute("bridge", dialstring);
            --  Check whether the client is webrtc or not
             if(transport_type ~= nil and string.find(transport_type, "transport=ws") ~= nil) then
                 session:execute("set", "sip_secure_media=true");
                 session:execute("set", "media_webrtc=true");
                 session:execute("export", "media_webrtc=true");
                 session:execute("bridge", internal_dialstring);
                 --session:execute("bridge", "sofia/internal/${to_number}@vabsys.com;fs_path=sip:52.73.47.94;transport=tcp" );
             else
                session:execute("bridge", internal_dialstring);
             end
             session:answer();
             if(session:ready() == true) then
                session:execute("lua", "voicemail.lua "..JSON:encode(message));
             end
         else
           -- calls to external party using bandwidth.
           --local dialstring =  "sofia/gateway/bandwidth/"..message.data.options.to;
           --session:execute("bridge", dialstring);
             session:setVariable("to_number", message.data.options.to);
             session:execute("bridge", internal_dialstring);
         end
      elseif(message.data.cmd == "forwardcall") then
            from_type = message.data.options.from_type;
            session:setVariable("accountcode", message.data.options.user_id);
           if(type(message.data.options.to.extensions) == "table") then
                 caller_id = message.data.options.caller_id;
                 session:consoleLog("info", "caller_id:"..caller_id);
                 session:setVariable("effective_caller_id_number", caller_id);
             if(message.data.options.to.extensions[1] ~= nil) then
                 local extnid = message.data.options.to.extensions[1];
                 if(has_value(forwardcall_tolist, extnid)) then
                    session:answer();
                    session:execute("lua", "voicemail.lua "..JSON:encode(message));
                 else
                    table.insert(forwardcall_tolist, extnid);
                    if(from_type ~= nil and from_type == "internal_s") then
                       local startidx = string.find(extnid, "xen");
                       if(startidx ~= nil) then
                          extnid = string.sub(extnid, startidx+3);
                       end
                    end
                    session:setVariable("from_type", from_type);
                    session:transfer(extnid, "XML", "AJR");
                 end
             elseif(message.data.options.to.internal[1] ~= nil) then
                 local to_nbr = message.data.options.to.internal[1];
                 if(has_value(forwardcall_tolist, to_nbr)) then
                    session:answer();
                    session:execute("lua", "voicemail.lua "..JSON:encode(message));
                 else
                    table.insert(forwardcall_tolist, to_nbr);
                    session:transfer(to_nbr, "XML", "AJR");
                 end
             elseif(message.data.options.to.external[1] ~= nil) then
                if(has_value(forwardcall_tolist, message.data.options.to.external[1])) then
                   session:answer();
                   session:execute("lua", "voicemail.lua "..JSON:encode(message));
                else
                   -- ring the external number for 20 seconds, if no-answer take the call to voicemail.
                   -- set the ignore_early_media=true is required otherwise, call_timeout will not work.
                   session:execute("set", "call_timeout=20");
                   session:execute("set", "ignore_early_media=true");
                   session:execute("set", "continue_on_fail=1,3,17,18,19,21,27,41,606");
                   session:execute("set", "hangup_after_bridge=true");
                   --session:execute("set", "transfer_ringback=$${us-ring}");
                   dialstring =  "sofia/gateway/bandwidth/"..message.data.options.to.external[1];
                   session:execute("bridge", dialstring);
                   --session:execute("transfer", external_nbr);                 
                   session:answer();
                   if(session:ready() == true) then
                      session:execute("lua", "voicemail.lua "..JSON:encode(message));
                   end
                end
             end
           end 
      elseif(message.data.cmd == "dnd")then
          session:setVariable("DIALSTATUS", "DND");
          session:execute("hangup", "SUBSCRIBER_ABSENT");
      elseif(message.data.cmd == "hangup") then
          session:setVariable("DIALSTATUS", "NONUMBER");
          session:execute("hangup", "NO_ROUTE_DESTINATION");
      elseif(message.data.cmd == "goto_voicemail")then
         session:answer();
         session:execute("lua", "voicemail.lua "..JSON:encode(message));
      elseif(message.data.cmd == "goto_menu")then
         session:answer();
         session:execute("lua", "ivrMenu.lua "..JSON:encode(message));
      end
   elseif(message["status"] == "error") then
       session:answer();
       session:execute("set", "tts_engine=flite")
       session:execute("set", "tts_voice=kal");
       session:execute("speak", "We are extremely sorry for the inconvenience. Some aplication error occurred. Please try again after some time"
);
       session:hangup();       
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
       session:answer();
       session:execute("set", "tts_engine=flite")
       session:execute("set", "tts_voice=kal");
       session:execute("speak", "We are extremely sorry for the inconvenience. Some aplication error occurred. Please try again after some time");
       session:hangup();
     else       
        return curl_respone;
     end
  end
end
local hex_to_char = function(x)
  return string.char(tonumber(x, 16))
end

local unescape = function(url)
  return url:gsub("%%(%x%x)", hex_to_char)
end


if(session:ready() == true) then
  original_caller_id = session:getVariable("caller_id_number");
  --local last_char = string.sub(original_caller_id, 1, -2);
  --session:consoleLog("err", last_char);
  --local device_type  = string.find(original_caller_id, "[wms]",#original_caller_id -1);
  --session:consoleLog("err","DEVICE:"..device_type);
  --find the last character in sip id. If it is one of w or m or s then replace with space.
  --last char is used to identify the device type like mobile(m), broswer(w), sip phone(s).
  if(string.find(original_caller_id, "[wms]",#original_caller_id -1) ~= nil) then
     original_caller_id = string.sub(original_caller_id, 1, -2);
  end
  local destination = session:getVariable("destination_number");
  local dial_string = session:getVariable("internal_dialstring");
  -- if the calle is on web then we need to add xtra session parameters.
  -- kamailio sends whether calle is active on web or not.
  --transport_type =  session:getVariable("sip_h_X-Destination-Transport");
  transport_type =  session:getVariable("sip_h_X-Destinations");
  session:consoleLog("err", transport_type);
  internal_dialstring = unescape(dial_string);
  xen360_url = session:getVariable("xen360_url");
  app_token = session:getVariable("xen360_app_token");
  user_ip = session:getVariable("domain");
  forwardcall_tolist = {};
  local frtype = session:getVariable("from_type");
  table.insert(forwardcall_tolist, original_caller_id);
  callXenApi(original_caller_id, destination, frtype);
session:consoleLog("err", curl_response);
  parseJson(curl_response);
end

