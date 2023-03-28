import webserver
import string
import json
import persist

class SaunaPanel : Driver

    var settings
    var main_switch
    var regulation_state
    var set_point_min_value
    var set_point_max_value

    def init()
        self.settings = persist
        var settings_modified = false
        self.main_switch = false
        self.regulation_state = true
        self.set_point_min_value = 10
        self.set_point_max_value = 100
        if !self.settings.has("sauna_set_point")
            self.settings.sauna_set_point = 75
            settings_modified = true
        end
        if !self.settings.has("sauna_start_time")
            self.settings.sauna_start_time = tasmota.rtc()
            settings_modified = true
        end
        if settings_modified
            self.settings.save()
        end
        # setup date/time handling
        self.set_date_time()
        tasmota.add_cron("0 * * * * *", /->self.set_date_time(), "date_time")
        # setup button handling
        tasmota.add_rule('Button1#state', /->self.button_1_pressed())
        # tasmota.add_rule('Button2#state', button_2_pressed)
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

    #- create a method for adding a button to the main menu -#
    def web_add_main_button()
        webserver.content_send("<p></p><button onclick='la(\"&m_toggle_main_switch=1\");'>Hauptschalter An/Aus</button>")
    end

    def web_sensor()
        # main state
        if webserver.has_arg("m_toggle_main_switch")
            self.main_switch = !self.main_switch
        end
        var main_switch_text = "Aus"
        var text_color = "#ff0000"
        var power_value = 0
        if self.main_switch
            main_switch_text = "An"
            text_color = "#00ff00"
            power_value = 1
        end
        webserver.content_send(string.format("{s}Hauptschalter{m}<span style='color:%s'>%s</span>{e}", text_color, main_switch_text))
        tasmota.cmd(string.format('Nextion page0.btPower.val=%d', power_value))

        # regulation state
        var regulation_state_text = "Aus"
        text_color = "#ff0000"
        var regulation_value = 0
        if self.regulation_state
            regulation_state_text = "An"
            text_color = "#00ff00"
            regulation_value = 1
        end
        webserver.content_send(string.format("{s}Regelung{m}<span style='color:%s'>%s</span>{e}", text_color, regulation_state_text))
        tasmota.cmd(string.format('Nextion page0.btControl.val=%d', regulation_value))

        # regulation start time
        var time_string = tasmota.strftime("%H:%M:%S", self.settings.sauna_start_time['local'])
        var date_string = tasmota.strftime("%d.%m.%Y", self.settings.sauna_start_time['local'])
        var text_decoration = "none"
        if self.settings.sauna_start_time['local'] < tasmota.rtc()['local']
            text_decoration = "line-through"
        end
        webserver.content_send(string.format("{s}Startzeit{m}<span style='text-decoration:%s'>%s %s</span>{e}", text_decoration, time_string, date_string))

        # set point
        if webserver.has_arg("m_update_set_point")
            self.settings.sauna_set_point += int(webserver.arg("m_update_set_point"))
            if self.settings.sauna_set_point < self.set_point_min_value
                self.settings.sauna_set_point = self.set_point_min_value
            end
            if self.settings.sauna_set_point > self.set_point_max_value
                self.settings.sauna_set_point = self.set_point_max_value
            end
        end
        webserver.content_send(string.format("{s}Solltemperatur{m}<button style='width:2em;' onclick='la(\"&m_update_set_point=-5\");'>-5</button><button style='width:2em;' onclick='la(\"&m_update_set_point=-1\");'>-1</button> %d °C <button style='width:2em;' onclick='la(\"&m_update_set_point=1\");'>+1</button><button style='width:2em;' onclick='la(\"&m_update_set_point=5\");'>+5</button>{e}", self.settings.sauna_set_point))
        tasmota.cmd(string.format('Nextion nSetPoint.val=%d', self.settings.sauna_set_point))
    end

    def json_append()
        var message = string.format(",\"Sauna\":{\"Hauptschalter\":%s,\"Regelung\":%s,\"set_point\":%d}", str(self.main_switch), str(self.regulation_state), self.settings.sauna_set_point)
        tasmota.response_append(message)
    end

    def every_second()
        if self.main_switch
            if self.regulation_state
                if self.maximum_temperature() < self.settings.sauna_set_point
                    print(string.format("%f < %f", self.maximum_temperature(), self.settings.sauna_set_point))
                    if !tasmota.get_power()[0]
                        tasmota.set_power(0, true)
                    end
                else
                    print(string.format("%f >= %f", self.maximum_temperature(), self.settings.sauna_set_point))
                    if tasmota.get_power()[0]
                        tasmota.set_power(0, false)
                    end
                end
            else
                # print("regulation will start at xxx")
                if tasmota.get_power()[0]
                    tasmota.set_power(0, false)
                end
            end
        else
            if tasmota.get_power()[0]
                tasmota.set_power(0, false)
            end
        end
    end

    def maximum_temperature()
        var sensor_data = json.load(tasmota.read_sensors())
        var maximum = sensor_data["DS18B20-1"]["Temperature"] >= sensor_data["DS18B20-2"]["Temperature"] ? sensor_data["DS18B20-1"]["Temperature"] : sensor_data["DS18B20-2"]["Temperature"]
        return maximum
    end

    def minimum_temperature()
        var sensor_data = json.load(tasmota.read_sensors())
        var minimum = sensor_data["DS18B20-1"]["Temperature"] <= sensor_data["DS18B20-2"]["Temperature"] ? sensor_data["DS18B20-1"]["Temperature"] : sensor_data["DS18B20-2"]["Temperature"]
        return minimum
    end

    def average_temperature()
        var sensor_data = json.load(tasmota.read_sensors())
        var average = (sensor_data["DS18B20-1"]["Temperature"] + sensor_data["DS18B20-2"]["Temperature"]) / 2
        return average
    end

    def temperature_difference()
        var sensor_data = json.load(tasmota.read_sensors())
        var difference = (sensor_data["DS18B20-1"]["Temperature"] - sensor_data["DS18B20-2"]["Temperature"])
        difference = difference < 0 ? -difference : difference
        return difference
    end

    def button_1_pressed(value, trigger, msg)
        print("button 1 event!!!")
        print("value: "+str(value))
        print("trigger: "+str(trigger))
        print("msg: "+str(msg))
    #     var power_state=tasmota.get_power()
    #     tasmota.set_power(0, !power_state[0])
    #     tasmota.cmd("Nextion dim=50")
    #     tasmota.cmd("Nextion tmScreensaver.en=1")
    end

end

sauna_panel = SaunaPanel()
tasmota.add_driver(sauna_panel)

# requires SetOption73 to decouple buttons from relays
if(tasmota.get_option(73)==1)
    print("SetOption73 already active")
else
    print("activating SetOption73")
    tasmota.cmd("SetOption73 1")
end
