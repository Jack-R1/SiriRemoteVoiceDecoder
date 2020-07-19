# Decode Apple TV 4th Gen Remote/ Siri Remote voice data

This is the fruits of my work to integrate the Apple TV remote with macOS

If you have an apple tv 4th gen remote lying around that you have tried to pair
with your mac, you quickly realize you have to use external tools like SiriMote
to extend the functions of the remote on your system however SiriMote does not allow
you to use the mic function on the remote with your system and as far as 
I know no other tool allows you to do this.

This application is the first of two whois purpose is to decode the packets
sent from the remote to a wav file on your computer that you can play on your machine
as a proof of concept.

To get this application to work you will need to follow the below steps. 
One major hurdle to getting the voice data from the remote is having to use XCode Additional 
tools -> PacketLogger to capture the data as I could not find an easy way to get the bluetooth 
le data from the remote as the OS protects the hid uuid service. Short of having to write 
a kext driver or reverse engineer a private framework like Media Remote Protocol on macOS 
(https://medium.com/@evancoleman/apple-tv-meet-my-lights-dissecting-the-media-remote-protocol-d07d1909ad82)
there is no easy way to getting this data within a standalone application.


Pre tasks:
Make sure you mac supports bluetooth le so your siri remote can pair with your mac

Tools you will need:

	a. Additional Tools for Xcode 10.1 or above (https://developer.apple.com/xcode/)
	b. SiriRemoteVoiceDecode app from my github repository (https://github.com/Jack-R1/SiriRemoteVoiceDecode)
	
Steps:
1. Open System Preferences -> Bluetooth

2. Hold Volume Up & Menu on your remote

3. When you see your remote show up in Devices, click on connect
   
   Note if the remote fails to pair, turn bluetooth off for 30 seconds
   then turn back on and reattempt the previous step to put your remote in
   pairing mode, basically keep trying again until you pair with your mac

4. At this point your remote should be paired to your mac and when you press volume up or down 
   it should trigger volume control on your mac

5. Get the bluetooth mac address of your siri remote and note it to be used later in the steps.
   
   One way to do this is to hold option key and select Bluetooth in menu bar and it should
   show the devices and their mac address, e.g AA-BB-CC-DD-EE-FF, replace any dashes with 
   colons, AA-BB-CC-DD-EE-FF -> AA:BB:CC:DD:EE:FF
   
6. Create folder called SiriRemote on your desktop

7. Download Additional Tools for Xcode 10.1 or above
   
   Download the version supported by your macOS, 
   
   for High Sierra you can use 10.1,
   
   for Catalina you can use 11.4

8. Open the Additional Tools Package you have downloaded

9. Under Hardware folder, copy PacketLogger.app to SiriRemote folder you
   created on your desktop

10. Download SiriRemoteVoiceDecode app (https://github.com/Jack-R1/SiriRemoteVoiceDecode)
	
    or you can download and build from the project files.

11. Copy the app to SiriRemote folder you created on your desktop

12. Open terminal (Launchpad -> Other -> Terminal) 

13. Change directory to SiriRemote folder on your desktop
	
    cd ~/Desktop

14. Run the below command in terminal, replace AA:BB:CC:DD:EE:FF with the remote MAC address you obtained 
	in the earlier steps.
  
	  sudo ./PacketLogger.app/Contents/Resources/packetlogger convert -s -f nhdr | ./SiriRemoteVoiceDecode AA:BB:CC:DD:EE:FF

    You will be prompted for your sudo password as xcode packetlogger needs to run in elevated privileges

    you can also do

    echo "password" | sudo -S ./PacketLogger_10.1.app/Contents/Resources/packetlogger convert -s -f nhdr | ./SiriRemoteVoiceDecode AA:BB:CC:DD:EE:FF

    This will pipe your password to packet logger so you dont always have to type it in but I would not recommend to show your
    password in plain site. Note the -S after sudo.

15. At this point press volume up or down on your remote, you should see messages on the console.
	
    If you dont, try these options:
  
		a. press control + c, to terminate the command, and then press up and enter to run it again
    
		b. leaving the command still running, disconnect your siri remote from bluetooth in
		system preferences (just disconnect, dont unpair) and then reconnect

16. Now press and hold the mic button and speak in to the remote, it should indicate
	  when voice data starts and ends on the console.

17. At this point frames.txt file should be created in SiriRemote folder on your desktop
	  containing the Opus voice data frames from the siri remote
	
18. And there should be decoded.wav file in SiriRemote folder with the decoded wav output
	  that you can play in a media player.


Next you can have a look at the other application (https://github.com/Jack-R1/SiriRemoteVoiceControl)
to integrate siri remote with your mac for voice control and even touch control (note touch is done
by third party application thanks to https://github.com/calftrail/TrackMagic)

