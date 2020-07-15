//
//  main.m
//  SiriRemoteVoiceDecoder
//
//  Created by Jack on 12/1/20.
//  Copyright © 2020 JackR1. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OKDecoder.h"

@interface NSData (Hexadecimal)
- (NSData *)initWithHexadecimalString:(NSString *)string;
+ (NSData *)dataWithHexadecimalString:(NSString *)string;
@end

unsigned char _hexCharToInteger(unsigned char hexChar) {
    if (hexChar >= '0' && hexChar <= '9') {
        return (hexChar - '0') & 0xF;
    } else {
        return ((hexChar - 'A')+10) & 0xF;
    }
}

@implementation NSData (Hexadecimal)
- (id)initWithHexadecimalString:(NSString *)string {
    const char * hexstring = [string UTF8String];
    int dataLength = [string length] / 2;
    unsigned char * data = malloc(dataLength);
    if (data == nil) {
        return nil;
    }
    int i = 0;
    for (i = 0; i < dataLength; i++) {
        unsigned char firstByte = hexstring[2*i];
        unsigned char secondByte = hexstring[2*i+1];
        unsigned char byte = (_hexCharToInteger(firstByte) << 4) + _hexCharToInteger(secondByte);
        data[i] = byte;
    }
    self = [self initWithBytes:data length:dataLength];
    free(data);
    return self;
}

+ (NSData *)dataWithHexadecimalString:(NSString *)string {
    return [[self alloc] initWithHexadecimalString:string];
}
@end

@implementation NSString (TrimmingAdditions)

- (NSString *)stringByTrimmingLeadingCharactersInSet:(NSCharacterSet *)characterSet {
    NSUInteger location = 0;
    NSUInteger length = [self length];
    unichar charBuffer[length];
    [self getCharacters:charBuffer];
    
    for (location; location < length; location++) {
        if (![characterSet characterIsMember:charBuffer[location]]) {
            break;
        }
    }
    
    return [self substringWithRange:NSMakeRange(location, length - location)];
}

- (NSString *)stringByTrimmingTrailingCharactersInSet:(NSCharacterSet *)characterSet {
    NSUInteger location = 0;
    NSUInteger length = [self length];
    unichar charBuffer[length];
    [self getCharacters:charBuffer];
    
    for (length; length > 0; length--) {
        if (![characterSet characterIsMember:charBuffer[length - 1]]) {
            break;
        }
    }
    
    return [self substringWithRange:NSMakeRange(location, length - location)];
}

@end

void c_print(NSString* prnt)
{
    printf("%s", [prnt cStringUsingEncoding:NSUTF8StringEncoding]);
    //fflush(stdout);
}

void c_print_ln(NSString* prnt)
{
    printf("%s\n", [prnt cStringUsingEncoding:NSUTF8StringEncoding]);
    //fflush(stdout);
}

NSString* read_till(char c)
{
    NSMutableString* ret = [[NSMutableString alloc] initWithString:@""];
    
    char r = getchar();
    while(r!=c && r!= '\0')
    {
        [ret appendFormat:@"%c",r];
        r = getchar();
    }
    return ret;
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        //After pairing your apple tv 4/siri remote to your computer,
        //you can find your siriRemote <MAC> address either via system preferences -> bluetooth
        //or by running packetlogger in terminal on its own, the first few lines will be
        //the bluetooth devices it has found
        NSString* siriRemoteMACAddress = [[NSMutableString alloc] initWithString:@""];
        
        //printf("argc: %d\n",argc);
        
        //If you dont pass in the <MAC> address, it will parse all data from packetlogger
        //that look like siri remote data but this is not recommended as the voice data
        //frames can be misinterpreted
        if(argc>1)
        {
            siriRemoteMACAddress = [[NSString alloc] initWithCString:argv[1] encoding:NSUTF8StringEncoding];
            //c_print_ln(siriRemoteMACAddress);
        }
        
        bool voiceStarted = false;
        bool voiceEnded = false;
        
        //where in the input line the byte data begins
        int index_data = 54;
        NSString* inputLine = [[NSMutableString alloc] initWithString:@""];
        
        //where in the byte data the voice data begins
        int index_b8 = 54;
        NSString* inputData = [[NSMutableString alloc] initWithString:@""];
        
        //frames will contain the concatenation of multiple frame strings
        NSString* frames = [[NSMutableString alloc] initWithString:@""];
        //frame will contain the byte data (sent by packetlogger spanning multiple lines) as a string
        NSString* frame = [[NSMutableString alloc] initWithString:@""];
        
        //init the opusDecoder to decode at 16Khz and 1 channel
        //The codec, khz and channel was identified by looking at the call the apple tv remote iOS app uses
        //to communicate to an apple tv box
        //see work of github project https://github.com/jeanregisser/mediaremotetv-protocol/tree/master/examples
        //
        /*
         type: REGISTER_VOICE_INPUT_DEVICE_MESSAGE
         identifier: "E85681B1-0EFA-4F13-B35B-AE27490F968E"
         priority: 0
         [registerVoiceInputDeviceMessage] {
           deviceDescriptor {
             defaultFormat {
               formatSettingsPlistData: "bplist00\323\001\002\003\004\005\006_\020\017AVSampleRateKey]AVFormatIDKey_\020\025AVNumberOfChannelsKey#@\317@\000\000\000\000\000\022opus\020\001\010\017!/GPU\000\000\000\000\000\000\001\001\000\000\000\000\000\000\000\007\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000W"
             }
             supportedFormats {
               formatSettingsPlistData: "bplist00\323\001\002\003\004\005\006_\020\017AVSampleRateKey]AVFormatIDKey_\020\025AVNumberOfChannelsKey#@\317@\000\000\000\000\000\022opus\020\001\010\017!/GPU\000\000\000\000\000\000\001\001\000\000\000\000\000\000\000\007\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000W"
             }
           }
         }
        
        1. formatSettingsPlistData is a string escaped with c style escape \nnn
           (The byte whose numerical value is given by nnn interpreted as an octal number)
        2. Convert formatSettingsPlistData string into hex bytes
        3. Then use plutil to convert to xml, see below
                
         <?xml version="1.0" encoding="UTF-8"?>
         <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
         <plist version="1.0">
         <dict>
             <key>AVFormatIDKey</key>
             <integer>1869641075</integer>
             <key>AVNumberOfChannelsKey</key>
             <integer>1</integer>
             <key>AVSampleRateKey</key>
             <real>16000</real>
         </dict>
         </plist>
        
        int value 1869641075 (AVFormatIDKey) is macOS AVFoundation/CoreAudio constant kAudioFormatOpus
        */
        OKDecoder *opusDecoder = [[OKDecoder alloc] initWithSampleRate:16000 numberOfChannels:1];
        
        NSError *error = nil;
        
        if (![opusDecoder setupDecoderWithError:&error]) {
            NSLog(@"Error setting up opus decoder: %@", error);
        }
        
        //set debug to true to read the frames from file instead of packetlogger,
        //say you want to breakpoint in xcode
        bool debug = false;
        
        if(debug)
        {
            //Simulate from voice ended...
            
            //decode opus codec packets
            NSMutableData * decodedRawAudio = [[NSMutableData alloc] init];
            
            //get frames from file
            frames = [NSString stringWithContentsOfFile:@"frames.txt"
                                               encoding:NSUTF8StringEncoding
                                                  error:NULL];
            
            for (NSString * frame in [frames componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]])
            {
                //make sure its not a corrupted frame and it contains the packetHeader at the first byte
                if([frame length] > (1 * 3))
                {
                    NSData * frameData = [NSData dataWithHexadecimalString:[frame stringByReplacingOccurrencesOfString:@" " withString: @""]];
                    NSData * packetHeader = [frameData subdataWithRange:NSMakeRange(0, 1)];
                    
                    int8_t packetLen;
                    [packetHeader getBytes:&packetLen length:1];
                    
                    //NSLog(@"packetLen = %d", packetLen);
                    
                    //frameData length (which includes the first byte packetHeader) should be greater than packetLen
                    if([frameData length] > packetLen)
                    {
                        //NSLog(@"frame = %@", [frame stringByReplacingOccurrencesOfString:@" " withString: @""]);
                        NSData * packetData = [frameData subdataWithRange:NSMakeRange(1, packetLen)];
                        
                        [opusDecoder decodePacket:packetData completionBlock:^(NSData *pcmData, NSUInteger numDecodedSamples, NSError *error) {
                            if (error) {
                                NSLog(@"Error decoding packet: %@", error);
                                return;
                            }
                            
                            [decodedRawAudio appendData:pcmData];
                        }];
                    }
                    else
                    {
                        NSLog(@"frame = %@", [frame stringByReplacingOccurrencesOfString:@" " withString: @""]);
                        NSLog(@"frame length %lu is less than required packetLen %d", [frameData length], packetLen);
                    }
                }
            }
            
            //crude but will do for now
            //sleep for 4 secs to let the last of the frames to be processed by
            //[opusDecoder decodePacket:packetData...] completion block finish up
            [NSThread sleepForTimeInterval:4.0f];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            [fileManager createFileAtPath:@"decoded.wav"  contents:nil attributes:nil];
            
            FILE *fout;
            
            short NumChannels = 1;
            short BitsPerSample = 16;
            int SamplingRate = 16000;
            int numOfSamples = [decodedRawAudio length];
            
            int ByteRate = NumChannels*BitsPerSample*SamplingRate/8;
            short BlockAlign = NumChannels*BitsPerSample/8;
            int DataSize = NumChannels*numOfSamples*BitsPerSample/8;
            int chunkSize = 16;
            int totalSize = 36 + DataSize; //http://soundfile.sapp.org/doc/WaveFormat/
            short audioFormat = 1;
            
            if((fout = fopen([@"decoded.wav" cStringUsingEncoding:1], "w")) == NULL)
            {
                NSLog(@"Error opening out file: decoded.wav");
            }
            
            fwrite("RIFF", sizeof(char), 4,fout);
            fwrite(&totalSize, sizeof(int), 1, fout);
            fwrite("WAVE", sizeof(char), 4, fout);
            fwrite("fmt ", sizeof(char), 4, fout);
            fwrite(&chunkSize, sizeof(int),1,fout);
            fwrite(&audioFormat, sizeof(short), 1, fout);
            fwrite(&NumChannels, sizeof(short),1,fout);
            fwrite(&SamplingRate, sizeof(int), 1, fout);
            fwrite(&ByteRate, sizeof(int), 1, fout);
            fwrite(&BlockAlign, sizeof(short), 1, fout);
            fwrite(&BitsPerSample, sizeof(short), 1, fout);
            fwrite("data", sizeof(char), 4, fout);
            fwrite(&DataSize, sizeof(int), 1, fout);
            
            fclose(fout);
            
            NSFileHandle *handle;
            handle = [NSFileHandle fileHandleForUpdatingAtPath:@"decoded.wav"];
            [handle seekToEndOfFile];
            [handle writeData:decodedRawAudio];
            [handle closeFile];
            
            //decoded.wav file should be available and can be opened in media player to hear the contents of what was spoken on the SiriRemote
        }
        else
        {
            //while loop to take in piped | data from packetlogger
            while(1)
            {
                inputLine = read_till('\n');
                //c_print_ln(inputLine);
                
                if(
                   (
                    [siriRemoteMACAddress isEqualToString:@""] ||      //they did not pass in the mac address or
                    [inputLine containsString:@"00:00:00:00:00:00"] || //packetlogger did register the correct mac address (it sometimes can do that) or
                    [inputLine containsString:siriRemoteMACAddress]    //or the mac address matches
                    ) &&
                   [inputLine containsString:@"RECV"])
                {
                    inputData = [[inputLine substringFromIndex:index_data] stringByTrimmingTrailingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    
                    //c_print_ln([[NSString alloc] initWithFormat:@"Reading in: %@",inputData]);
                    
                    //start of voice command
                    if([inputData hasSuffix: @"1B 23 00 00 10"])
                    {
                        printf("Voice started...\n");
                     
                        //empty out frames and frame on voice start
                        frames = [[NSMutableString alloc] initWithString:@""];
                        frame = [[NSMutableString alloc] initWithString:@""];
                        
                        voiceStarted = true;
                        voiceEnded = false;
                    }
                    //end of voice command
                    else if([inputData hasSuffix: @"1B 23 00 10 00"])
                    {
                        printf("Voice ended...\n");
                        
                        voiceStarted = false;
                        voiceEnded = true;
                        
                        //decode opus codec packets
                        NSMutableData * decodedRawAudio = [[NSMutableData alloc] init];
                        
                        BOOL succeed = [frames writeToFile:@"frames.txt"
                                                  atomically:YES encoding:NSUTF8StringEncoding error:&error];
                        if (!succeed){
                            NSLog(@"Error saving frames to file: %@", error);
                        }
                        
                        for (NSString * frame in [frames componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]])
                        {
                            //make sure its not a corrupted frame and it contains the packetHeader at the first byte
                            if([frame length] > (1 * 3))
                            {
                                NSData * frameData = [NSData dataWithHexadecimalString:[frame stringByReplacingOccurrencesOfString:@" " withString: @""]];
                                NSData * packetHeader = [frameData subdataWithRange:NSMakeRange(0, 1)];
                                
                                int8_t packetLen;
                                [packetHeader getBytes:&packetLen length:1];
                                
                                //NSLog(@"packetLen = %d", packetLen);
                                
                                //frameData length (which includes the first byte packetHeader) should be greater than packetLen
                                if([frameData length] > packetLen)
                                {
                                    //NSLog(@"frame = %@", [frame stringByReplacingOccurrencesOfString:@" " withString: @""]);
                                    NSData * packetData = [frameData subdataWithRange:NSMakeRange(1, packetLen)];
                                    
                                    [opusDecoder decodePacket:packetData completionBlock:^(NSData *pcmData, NSUInteger numDecodedSamples, NSError *error) {
                                        if (error) {
                                            NSLog(@"Error decoding packet: %@", error);
                                            return;
                                        }
                                        
                                        [decodedRawAudio appendData:pcmData];
                                    }];
                                }
                                else
                                {
                                    NSLog(@"frame = %@", [frame stringByReplacingOccurrencesOfString:@" " withString: @""]);
                                    NSLog(@"frame length %lu is less than required packetLen %d", [frameData length], packetLen);
                                }
                            }
                            
                        }
                        
                        //crude but will do for now
                        //sleep for 4 secs to let the last of the frames to be processed by
                        //[opusDecoder decodePacket:packetData...] completion block finish up
                        [NSThread sleepForTimeInterval:4.0f];
                        
                        NSFileManager *fileManager = [NSFileManager defaultManager];
                        [fileManager createFileAtPath:@"decoded.wav"  contents:nil attributes:nil];
                        
                        FILE *fout;
                        
                        short NumChannels = 1;
                        short BitsPerSample = 16;
                        int SamplingRate = 16000;
                        int numOfSamples = [decodedRawAudio length];
                        
                        int ByteRate = NumChannels*BitsPerSample*SamplingRate/8;
                        short BlockAlign = NumChannels*BitsPerSample/8;
                        int DataSize = NumChannels*numOfSamples*BitsPerSample/8;
                        int chunkSize = 16;
                        int totalSize = 46 + DataSize;
                        short audioFormat = 1;
                        
                        if((fout = fopen([@"decoded.wav" cStringUsingEncoding:1], "w")) == NULL)
                        {
                            NSLog(@"Error opening out file: decoded.wav");
                        }
                        
                        fwrite("RIFF", sizeof(char), 4,fout);
                        fwrite(&totalSize, sizeof(int), 1, fout);
                        fwrite("WAVE", sizeof(char), 4, fout);
                        fwrite("fmt ", sizeof(char), 4, fout);
                        fwrite(&chunkSize, sizeof(int),1,fout);
                        fwrite(&audioFormat, sizeof(short), 1, fout);
                        fwrite(&NumChannels, sizeof(short),1,fout);
                        fwrite(&SamplingRate, sizeof(int), 1, fout);
                        fwrite(&ByteRate, sizeof(int), 1, fout);
                        fwrite(&BlockAlign, sizeof(short), 1, fout);
                        fwrite(&BitsPerSample, sizeof(short), 1, fout);
                        fwrite("data", sizeof(char), 4, fout);
                        fwrite(&DataSize, sizeof(int), 1, fout);
                        
                        fclose(fout);
                        
                        NSFileHandle *handle;
                        handle = [NSFileHandle fileHandleForUpdatingAtPath:@"decoded.wav"];
                        [handle seekToEndOfFile];
                        [handle writeData:decodedRawAudio];
                        [handle closeFile];
                        
                        //get out of the while loop
                        //decoded.wav file should be available and can be opened in media player to hear the contents of what was spoken on the SiriRemote
                        break;
                    }
                    //concatenate data over multiple lines into a frame and of which into frames
                    else {
                        if(voiceStarted)
                        {
                            //length of line should be 31 bytes (2 char with space), less space at the end
                            if([inputData length] == (31 * 3) - 1 )
                            {
                                //Is this line the frame header?
                                //Does it start with 40 20 instead of 40 10 and have B8
                                if([inputData hasPrefix: @"40 20"] &&
                                   [[inputData substringWithRange:NSMakeRange(index_b8, 2)] isEqual:@"B8"])
                                {
                                    //if the previous frame is not empty then add the last frame to list of frames
                                    if(![frame isEqualToString:@""])
                                    {
                                        printf("Frame is: %s\n", [frame cStringUsingEncoding:NSUTF8StringEncoding]);
                                        
                                        //add the last frame to the list of frames
                                        if([frames isEqualToString:@""])
                                            frames = [[NSString alloc] initWithFormat:@"%@", frame];
                                        else
                                            frames = [[NSString alloc] initWithFormat:@"%@\n%@", frames, frame];
                                        
                                    }
                                    
                                    //voice data begins at B8 however we include the byte before B8
                                    //as this is the length of voice data in 0xhh in the frame
                                    frame = [[NSString alloc] initWithFormat:@"%@", [inputData substringFromIndex:index_b8-3]];
                                }
                                else
                                {
                                    //if this is not a frame header line, then its a subsequent data line for an existing frame
                                    //so the rest of the voice data should start after 4th byte and have length of 27 bytes
                                    frame = [[NSString alloc] initWithFormat:@"%@ %@", frame, [inputData substringFromIndex:4*3]];
                                }
                            }
                        }
                        
                    }
                }
            }
        }
        
    }
    return 0;
}
