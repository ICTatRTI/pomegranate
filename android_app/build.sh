#!/bin/bash
adb uninstall org.rti.pomegranate
ant debug
adb install bin/pomegranate-debug.apk
adb shell am start -n org.rti.pomegranate/org.rti.pomegranate.pomegranate
