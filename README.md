# SacDaq
Data logging framework for Linux

This is a data logging system (for things like weather sensors) designed to run on embedded Linux boards like Raspberry Pi.
It consists of sensor drivers that collect the data (included drivers support various I2C/SPI-connected temperature,
humidity, pressure, and ADC chips, an collection agent that calls configured drivers at specified time intervals and records the results to a database, and a web application and API for storing and displaying the data.
