load("lovelace.be")

def button_1_pressed(value, trigger, msg)
    print("button 1 event!!!")
    print("value: "+str(value))
    print("trigger: "+str(trigger))
    print("msg: "+str(msg))
    var power_state=tasmota.get_power()
    tasmota.set_power(0, !power_state[0])
    tasmota.cmd("Nextion dim=50")
    tasmota.cmd("Nextion tmScreensaver.en=1")
end

def button_2_pressed(value, trigger, msg)
    print("button 2 event!!!")
    print("value: "+str(value))
    print("trigger: "+str(trigger))
    print("msg: "+str(msg))
end

# sets time and date according to Tasmota local time
def set_clock()
    var now = tasmota.rtc()
    var time_raw = now['local']
    var nsp_time = tasmota.time_dump(time_raw)
    var time_string = (nsp_time["hour"] < 10 ? "0" : "") + str(nsp_time["hour"]) + ":" + (nsp_time["min"] < 10 ? "0" : "") + str(nsp_time["min"])
    tasmota.cmd('Nextion vaTime.txt="' + time_string + '"')
    log('Time synced with ' + time_string, 3)
end

# sets date according to Tasmota local time
def set_date()
    var now = tasmota.rtc()
    var time_raw = now['local']
    var nsp_time = tasmota.time_dump(time_raw)
    var date_string = (nsp_time["day"] < 10 ? "0" : "") + str(nsp_time['day']) + "." + (nsp_time["month"] < 10 ? "0" : "") + str(nsp_time['month']) + "." + str(nsp_time['year'])
    tasmota.cmd('Nextion vaDate.txt="' + date_string + '"')
    log('Date synced with ' + date_string, 3)
end

# requires SetOption73 to decouple buttons from relays
if(tasmota.get_option(73)==1)
    print("SetOption73 already active")
else
    print("activating SetOption73")
    tasmota.cmd("SetOption73 1")
end

# time
tasmota.add_rule("Time#Initialized", set_clock)
tasmota.add_rule("Time#Minute", set_clock)
# date
tasmota.add_rule("Time#Initialized", set_date)
tasmota.add_rule("Time#Minute=0", set_date)
# buttons
tasmota.add_rule('Button1#state', button_1_pressed)
tasmota.add_rule('Button2#state', button_2_pressed)
