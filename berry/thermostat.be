import string
import webserver
import persist

class SaunaPanel : Driver

    var settings
    var settings_modified
    var set_point_min_value
    var set_point_max_value

    def init()
        # init global variables
        self.set_point_min_value = 50
        self.set_point_max_value = 100
        # set temperature sensor
        tasmota.cmd("SensorInputSet 1")

        # init persisted settings
        self.settings = persist
        self.settings_modified = false
        if !self.settings.has("sauna_set_point")
            self.update_set_point(self.set_point_min_value)
        else
            self.update_set_point(self.settings.sauna_set_point)
        end
        if !self.settings.has("sauna_temperature_hysteresis")
            self.update_sauna_temperature_hysteresis(2)
        else
            self.update_sauna_temperature_hysteresis(self.settings.sauna_temperature_hysteresis)
        end
        if !self.settings.has("sauna_start_time")
            self.settings.sauna_start_time = tasmota.rtc()
            self.settings_modified = true
        end
        if !self.settings.has("sauna_time_pi_cycle")
            self.update_sauna_time_pi_cycle(10)
        else
            self.update_sauna_time_pi_cycle(self.settings.sauna_time_pi_cycle)
        end
        if !self.settings.has("sauna_time_max_action")
            self.update_sauna_time_max_action(8)
        else
            self.update_sauna_time_max_action(self.settings.sauna_time_max_action)
        end
        if !self.settings.has("sauna_time_min_action")
            self.update_sauna_time_min_action(1)
        else
            self.update_sauna_time_min_action(self.settings.sauna_time_min_action)
        end
        self.save_settings()

        # save settings every hour
        tasmota.set_timer(60*60*1000, /->self.save_settings)

        # requires SetOption73 to decouple buttons from relays
        if tasmota.get_option(73) == 1
            print("SetOption73 already active")
        else
            print("activating SetOption73")
            tasmota.cmd("SetOption73 1")
        end

        # setup button handling
        tasmota.add_rule('Button1#state', /value, trigger, msg->self.button_1_pressed(value, trigger, msg))
        tasmota.add_rule('Button2#state', /value, trigger, msg->self.button_2_pressed(value, trigger, msg))

        # setup display input
        tasmota.add_rule('NextionReceived#set_point', /value->self.update_set_point(value))
        tasmota.add_rule('NextionReceived#thermostat_state', /->self.toggle_thermostat())
        # tasmota.add_rule('NextionReceived#light_state', /->self.toggle_light())
        # debugging rule
        tasmota.add_rule('NextionReceived#?', /value, trigger, msg->self.handle_display_input(value, trigger, msg))

        # setup date/time handling
        self.set_date_time()
        tasmota.add_cron("0 * * * * *", /->self.set_date_time(), "date_time")
    end

    def update_set_point(new_set_point)
        if new_set_point < self.set_point_min_value
            new_set_point = self.set_point_min_value
        end
        if new_set_point > self.set_point_max_value
            new_set_point = self.set_point_max_value
        end
        if new_set_point != self.settings.sauna_set_point
            self.settings.sauna_set_point = new_set_point
            self.settings_modified = true
        end
        # always update display and thermostat
        tasmota.cmd(string.format('TempTargetSet %d', self.settings.sauna_set_point))
        tasmota.cmd(string.format('Nextion nSetPoint.val=%d', self.settings.sauna_set_point))
        tasmota.cmd(string.format('Nextion hSetPoint.val=%d', self.settings.sauna_set_point))
    end

    def update_sauna_temperature_hysteresis(new_temperature_hysteresis)
        if new_temperature_hysteresis != self.settings.sauna_temperature_hysteresis
            self.settings.sauna_temperature_hysteresis = new_temperature_hysteresis
            self.settings_modified = true
        end
        # always update thermostat
        tasmota.cmd(string.format('TempHystSet %d', self.settings.sauna_temperature_hysteresis))
    end

    def update_sauna_time_pi_cycle(new_time_pi_cycle)
        if new_time_pi_cycle != self.settings.sauna_time_pi_cycle
            self.settings.sauna_time_pi_cycle = new_time_pi_cycle
            self.settings_modified = true
        end
        # always update thermostat
        tasmota.cmd(string.format('TimePiCycleSet %d', self.settings.sauna_time_pi_cycle))
    end

    def update_sauna_time_max_action(new_time_max_action)
        if new_time_max_action != self.settings.sauna_time_max_action
            self.settings.sauna_time_max_action = new_time_max_action
            self.settings_modified = true
        end
        # always update thermostat
        tasmota.cmd(string.format('TimeMaxActionSet %d', self.settings.sauna_time_max_action))
    end

    def update_sauna_time_min_action(new_time_min_action)
        if new_time_min_action != self.settings.sauna_time_min_action
            self.settings.sauna_time_min_action = new_time_min_action
            self.settings_modified = true
        end
        # always update thermostat
        tasmota.cmd(string.format('TimeMinActionSet %d', self.settings.sauna_time_min_action))
    end

    # check if settings changed
    def save_settings()
        if self.settings_modified
            print("saving settings")
            self.settings.save()
            self.settings_modified = false
        else
            print("settings not modified")
        end
    end

    # save our settings
    def save_before_restart()
        self.save_settings()
    end

    # sets time and date according to Tasmota local time
    def set_date_time()
        var local_rtc = tasmota.rtc()['local']
        if local_rtc < 50
            tasmota.set_timer(1000, /->self.set_date_time())
        else
            var time_string = tasmota.strftime("%H:%M", local_rtc)
            tasmota.cmd('Nextion vaTime.txt="' + time_string + '"')
            var date_string = tasmota.strftime("%d.%m.%Y", local_rtc)
            tasmota.cmd('Nextion vaDate.txt="' + date_string + '"')
        end
    end

    # create a method for adding a button to the main menu
    def web_add_main_button()
        webserver.content_send("<p></p><button onclick='la(\"&m_toggle_thermostat=1\");'>Thermostat An/Aus</button>")
    end

    def web_sensor()
        # thermostat state
        if webserver.has_arg("m_toggle_thermostat")
            self.toggle_thermostat()
        end

        # set point
        if webserver.has_arg("m_update_set_point")
            var new_set_point = self.settings.sauna_set_point + int(webserver.arg("m_update_set_point"))
            self.update_set_point(new_set_point)
        end
        webserver.content_send(string.format("{s}Solltemperatur{m}<button style='width:2em; margin-right:2px;' onclick='la(\"&m_update_set_point=-5\");'>-5</button><button style='width:2em;' onclick='la(\"&m_update_set_point=-1\");'>-1</button> %d °C <button style='width:2em;' onclick='la(\"&m_update_set_point=1\");'>+1</button><button style='width:2em; margin-left:2px;' onclick='la(\"&m_update_set_point=5\");'>+5</button>{e}", self.settings.sauna_set_point))
    end

    def toggle_thermostat()
        var thermostat_enabled = (tasmota.cmd("ThermostatModeSet1")['ThermostatModeSet1'] + 1) % 2
        tasmota.cmd("ThermostatModeSet " + str(thermostat_enabled))
        # update display
        tasmota.cmd('Nextion btThermostat.val=' + str(thermostat_enabled))
    end

    def toggle_light()
        # var thermostat_enabled = tasmota.cmd("ThermostatModeSet1")['ThermostatModeSet1']
        # tasmota.cmd("ThermostatModeSet " + str(thermostat_enabled))
        # # update display
        # tasmota.cmd('Nextion btLight.val=' + str(thermostat_enabled))
    end

    def button_1_pressed(value, trigger, msg)
        # print("button 1 event!!!")
        # print("value: "+str(value))
        # print("trigger: "+str(trigger))
        # print("msg: "+str(msg))
        if value == 10  # single button press
            self.toggle_thermostat()
        end
    end

    def button_2_pressed(value, trigger, msg)
        print("button 2 event!!!")
        print("value: "+str(value))
        print("trigger: "+str(trigger))
        print("msg: "+str(msg))
        if value == 10  # single button press
            self.toggle_light()
        end
    end

    def handle_display_input(value, trigger, msg)
        print("display input event!!!")
        print("value: "+str(value))
        print("trigger: "+str(trigger))
        print("msg: "+str(msg))
        if value == 10  # single button press
            self.toggle_light()
        end
    end

end

sauna_panel = SaunaPanel()
tasmota.add_driver(sauna_panel)
