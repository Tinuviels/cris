#!/bin/sh

#config section
#----------------------------------------------------------------------

#w1 fix
min_cons_t="0.7"
max_cons_t="1.5"

min_cons_h="0.2"
max_cons_h="4"

# DIGITAL:

#temp pin
pin_temp="4"

# off using analog sensor
#light pin:
#pin_light="19"

#soil moisture pin:
pin_hum="13"

#water pump pin:
pin_pump="26"

#water level pin:
pin_level=""

#air humidity/temperature pin:
pin_humtemp="4"

# ANALOG:

#analog soil moisture sensor script location:
ad_mois="/root/scripts/kwiatek/soil_moisture.py"

#analog soil moisture sensor calibration
ad_mois_a="-47.619"
ad_mois_b="147.62"

#analog light sensor script location:
ad_light="/root/scripts/kwiatek/light.py"

#analog light sensor calibration
ad_light_a="44871"
ad_light_b="-1.978"

#analog water level sensor script location:
ad_level="/root/scripts/kwiatek/water_level.py"

#analog water level sensor calibration
ad_level_a="11.429"

#water level warning in mm (0 to 40mm)
ad_level_war="10"

#sleep time after watering in seconds
sleep_wat="3600"
#------------------------------------------------------------------------

#setup GPIO section
#------------------------------------------------------------------------

#temperature sensor

#add modules
if ! grep -q  w1-gpio "/etc/modules"; then
        echo "w1-gpio" >> /etc/modules
fi

if ! grep -q  w1-therm "/etc/modules"; then
        echo "w1-therm" >> /etc/modules
fi

if ! grep -q  w1-gpio "/boot/config.txt"; then
        echo dtoverlay=w1-gpio,gpiopin=$pin_temp >> /boot/config.txt
fi

#load modules
modprobe w1-gpio
modprobe w1-therm

#get temperature sensor id
id_temp=`cat /sys/bus/w1/devices/w1_bus_master1/w1_master_slaves`

#ad converter

#add modules
if ! grep -q  i2c-dev "/etc/modules"; then
        echo "i2c-dev" >> /etc/modules
fi

#load modules
modprobe i2c-dev

#water pump
if [ ! -d /sys/class/gpio/gpio$pin_pump ]; then
	echo $pin_pump > /sys/class/gpio/export
	echo "out" > /sys/class/gpio/gpio$pin_pump/direction
        echo "1" > /sys/class/gpio/gpio$pin_pump/value
fi

# off, using analog sensor
#light sensor
#if [ ! -d /sys/class/gpio/gpio$pin_light ]; then
#        echo $pin_light > /sys/class/gpio/export
#        echo "in" > /sys/class/gpio/gpio$pin_light/direction
#fi

#humidity sensor
if [ ! -d /sys/class/gpio/gpio$pin_hum ]; then
        echo $pin_hum > /sys/class/gpio/export
        echo "in" > /sys/class/gpio/gpio$pin_hum/direction
fi

#------------------------------------------------------------------------

#run system
while true
do
   ct_day=`date +%F`
   ct_time=`date +%H:%M:%S`
   #make sure pump is off
   echo "1" > /sys/class/gpio/gpio$pin_pump/value

   #check lock file
   if [ `find /root/scripts/kwiatek -name "lock" -mmin +720` ]; then
   rm -f /root/scripts/kwiatek/lock
   fi

   ## off, using analog sensor
   #check light sensor
   #data_light=`cat /sys/class/gpio/gpio$pin_light/value`
   #
   #if [ "$data_light" = "1" ]; then
   #	data_light_h="NIE"
   #fi
   #
   #if [ "$data_light" = "0" ]; then
   #     data_light_h="TAK"
   #fi

   #check analog water level sensor
#   python $ad_level > /dev/null
#   python $ad_level > /root/scripts/kwiatek/data/ad_level.tmp
#   python $ad_level >> /root/scripts/kwiatek/data/ad_level.tmp
#   python $ad_level >> /root/scripts/kwiatek/data/ad_level.tmp

 #  ad_level_v=`cat /root/scripts/kwiatek/data/ad_level.tmp | awk '{ total += $1 } END { print total/NR }'`
 #  data_level_h=`echo "" | awk 'END {print (a*b)}' a="$ad_level_a" b="$ad_level_v"`

 #  bc_check=`echo "$data_level_h<$ad_level_war" | bc`

  # if [ ! -f /root/scripts/kwiatek/lock ];then

  # 	if [ $bc_check -eq "1" ]; then
  #      	echo `date` > /root/scripts/kwiatek/lock
  #      	echo "Konczy sie woda w zbiorniku, pozostalo $data_level_h mm." | slacktee.sh
  # 	fi
  # fi

   #check humidity sensor
   data_hum=`cat /sys/class/gpio/gpio$pin_hum/value`

   if [ "$data_hum" = "1" ]; then
        data_hum_h="NIE"
        if [ ! -f /root/scripts/kwiatek/lock ];then
        echo "Podlewam kwiatka" | slacktee.sh
        echo 0 > /sys/class/gpio/gpio$pin_pump/value
        sleep 1
        echo 1 > /sys/class/gpio/gpio$pin_pump/value
        echo `date` > /root/scripts/kwiatek/lock
	fi
   fi

   if [ "$data_hum" = "0" ]; then
        data_hum_h="TAK"
   fi

   #check air humidity and temperature sensor
   if [ -f /root/scripts/kwiatek/data/$ct_day'air_temp.txt' ] && [ `wc -l /root/scripts/kwiatek/data/$ct_day'air_temp.txt' | awk '{print $1}'` -ge "3" ]; then

   avg_temp=`tail -n 3 /root/scripts/kwiatek/data/$ct_day'air_temp.txt' | awk '{ total += $2 } END { print total/NR }' | cut -d "." -f 1`
   min_temp=`echo "" | awk 'END {print (a*b)}' a="$avg_temp" b="$min_cons_t" | cut -d "." -f 1`
   max_temp=`echo "" | awk 'END {print (a*b)}' a="$avg_temp" b="$max_cons_t" | cut -d "." -f 1`

   else

   min_temp="18"
   max_temp="30"
   fi

   if [ -f /root/scripts/kwiatek/data/$ct_day'air_hum.txt' ] && [ `wc -l /root/scripts/kwiatek/data/$ct_day'air_hum.txt' | awk '{print $1}'` -ge "3" ]; then

   avg_hum=`tail -n 3 /root/scripts/kwiatek/data/$ct_day'air_hum.txt' | awk '{ total += $2 } END { print total/NR }' | cut -d "." -f 1`
   min_hum=`echo "" | awk 'END {print (a*b)}' a="$avg_hum" b="$min_cons_h" | cut -d "." -f 1`
   max_hum=`echo "" | awk 'END {print (a*b)}' a="$avg_hum" b="$max_cons_h" | cut -d "." -f 1`

   else

   min_hum="20"
   max_hum="70"
   fi

   /root/scripts/kwiatek/AdafruitDHT.py 11 $pin_humtemp > /root/scripts/kwiatek/humtemp.tmp

   j=0
   until [ $j -gt 10 ]
   do

   j=$((j+1))

   	if ! grep -q Temp "/root/scripts/kwiatek/humtemp.tmp"; then
   		/root/scripts/kwiatek/AdafruitDHT.py 11 $pin_humtemp > /root/scripts/kwiatek/humtemp.tmp
   	fi
   done

   i=0
   until [ $i -gt 10 ]
   do

   i=$((i+1))

   data_air_hum_h_test=`cat /root/scripts/kwiatek/humtemp.tmp | cut -d "=" -f 3 | cut -d "%" -f 1 | cut -d "." -f 1`

        if [ "$data_air_hum_h_test" -gt "100" ]; then
                /root/scripts/kwiatek/AdafruitDHT.py 11 4 > /root/scripts/kwiatek/humtemp.tmp
        fi

       data_air_temp_test=`cat /root/scripts/kwiatek/humtemp.tmp | cut -d "=" -f 2 | cut -d "*" -f 1 | cut -d "." -f 1`
       data_air_hum_test=`cat /root/scripts/kwiatek/humtemp.tmp | cut -d "=" -f 3 | cut -d "%" -f 1 | cut -d "." -f 1`

       if ! grep -q  Failed "/root/scripts/kwiatek/humtemp.tmp"; then

       	if [ "$data_air_temp_test" -gt "$max_temp" ] || [ "$data_air_temp_test" -lt "$min_temp" ] ; then
       	         /root/scripts/kwiatek/AdafruitDHT.py 11 4 > /root/scripts/kwiatek/humtemp.tmp
       	fi

       	if [ "$data_air_hum_test" -gt "$max_hum" ] || [ "$data_air_hum_test" -lt "$min_hum" ] ; then
                 /root/scripts/kwiatek/AdafruitDHT.py 11 4 > /root/scripts/kwiatek/humtemp.tmp
       	fi

       fi

   done

   if ! grep -q  Failed "/root/scripts/kwiatek/humtemp.tmp"; then
   	data_air_temp_h=`cat /root/scripts/kwiatek/humtemp.tmp | cut -d "=" -f 2 | cut -d "*" -f 1`
        data_air_hum_h=`cat /root/scripts/kwiatek/humtemp.tmp | cut -d "=" -f 3 | cut -d "%" -f 1`
   else
  	data_air_temp_h="Failed to get air temperature."
  	data_air_hum_h="Failed to get air humidity."
   fi

   if [ "$data_air_hum_test" -eq "150" ] && [ "$data_air_temp_test" -eq "12" ];then
        data_air_temp_h="Failed to get air temperature."
        data_air_hum_h="Failed to get air humidity."
   fi

   #sleep to free w1
   sleep 5

   #check soil temperature sensor
   if [ -z "$id_temp" ];then
        data_temp_h="No temperature sensor detected"

   else

        data_temp_h=`cat  /sys/bus/w1/devices/$id_temp/w1_slave | tail -n 1 | cut -d "=" -f 2 | awk '{print $1/1000}'`

   fi

   #check analog light sensor
   python $ad_light > /dev/null
   python $ad_light > /root/scripts/kwiatek/data/ad_light.tmp
   python $ad_light >> /root/scripts/kwiatek/data/ad_light.tmp
   python $ad_light >> /root/scripts/kwiatek/data/ad_light.tmp

   ad_light_v=`cat /root/scripts/kwiatek/data/ad_light.tmp | awk '{ total += $1 } END { print total/NR }'`
   data_light_h=`echo "" | awk 'END {print (a*(b^c))}' a="$ad_light_a" b="$ad_light_v" c="$ad_light_b"`

   #check analog soil moisture sensor
   python $ad_mois > /dev/null
   python $ad_mois > /root/scripts/kwiatek/data/ad_mois.tmp
   python $ad_mois >> /root/scripts/kwiatek/data/ad_mois.tmp
   python $ad_mois >> /root/scripts/kwiatek/data/ad_mois.tmp

   ad_mois_v=`cat /root/scripts/kwiatek/data/ad_mois.tmp | awk '{ total += $1 } END { print total/NR }'`
   data_mois_h=`echo "" | awk 'END {print (a*b) + (c)}'  a="$ad_mois_a" b="$ad_mois_v" c="$ad_mois_b"`

   #write stats to files
   echo "$ct_time \t $data_hum_h" >> /root/scripts/kwiatek/data/$ct_day'earth_hum.txt'
   echo "$ct_time \t $data_temp_h" >> /root/scripts/kwiatek/data/$ct_day'earth_temp.txt'
   echo "$ct_time \t $data_light_h" >> /root/scripts/kwiatek/data/$ct_day'light.txt'
   echo "$ct_time \t $data_air_temp_h" >> /root/scripts/kwiatek/data/$ct_day'air_temp.txt'
   echo "$ct_time \t $data_air_hum_h" >> /root/scripts/kwiatek/data/$ct_day'air_hum.txt'
   echo "$ct_time \t $data_mois_h" >> /root/scripts/kwiatek/data/$ct_day'soil_mois.txt'
#   echo "$ct_time \t $data_level_h" >> /root/scripts/kwiatek/data/$ct_day'water_level.txt'
   echo "$ct_time \t $data_hum" >> /root/scripts/kwiatek/data/$ct_day'watering.txt'

   #slack
   #echo "Czy kwiatek jest podlany?" | slacktee.sh
   #sleep 2
   #tail -n 1 /root/scripts/kwiatek/data/$ct_day'hum.txt' | slacktee.sh
   #sleep 1
   #echo "Czy kwiatek ma światło?" | slacktee.sh
   #sleep 2
   #tail -n 1 /root/scripts/kwiatek/data/$ct_day'light.txt' | slacktee.sh

   #loop sleep value
   sleep 60
done
