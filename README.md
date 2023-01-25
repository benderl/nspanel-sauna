# nspanel-sauna

## References and sources

This project is based on several sources working with the Sonoff NSPanel:

- <https://github.com/blakadder/nspanel>
- <https://github.com/peepshow-21/ns-flash>
- <https://github.com/joBr99/nspanel-lovelace-ui>

## Goal

Replace an traditional sauna control panel with the Sonoff NSPanel.

- read two temperature sensors for safety reasons
- manage set-point temperature on display
- overheating protection
- maximum heating time
- timer based preheating

Additional ideas

- flash the light inside the sauna to indicate a preset session finished

## Hardware modifications

- use relay 3 pin to connect DS18B20 temperature sensors
- relay 1 controls a four terminal contactor to switch the sauna oven
