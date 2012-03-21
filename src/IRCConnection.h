/*
 * Copyright (c) 2010, 2011, Jonathan Schleifer <js@webkeks.org>
 *
 * https://webkeks.org/git/?p=objirc.git
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice is present in all copies.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import <ObjFW/OFObject.h>

@class OFString;
@class OFMutableDictionary;
@class OFTCPSocket;
@class IRCConnection;
@class IRCUser;
@class IRCChannel;

@protocol IRCConnectionDelegate
@optional
- (void)connection: (IRCConnection*)connection
    didReceiveLine: (OFString*)line;
- (void)connection: (IRCConnection*)connection
       didSendLine: (OFString*)line;
- (void)connectionWasEstablished: (IRCConnection*)connection;
- (void)connection: (IRCConnection*)connection
	didSeeUser: (IRCUser*)user
       joinChannel: (IRCChannel*)channel;
- (void)connection: (IRCConnection*)connection
	didSeeUser: (IRCUser*)user
      leaveChannel: (IRCChannel*)channel
	withReason: (OFString*)reason;
- (void)connection: (IRCConnection*)connection
        didSeeUser: (IRCUser*)user
  changeNicknameTo: (OFString*)nickname;
- (void)connection: (IRCConnection*)connection
	didSeeUser: (IRCUser*)user
	  kickUser: (OFString*)kickedUser
       fromChannel: (IRCChannel*)channel
	withReason: (OFString*)reason;
- (void)connection: (IRCConnection*)connection
    didSeeUserQuit: (IRCUser*)user
	withReason: (OFString*)reason;
-  (void)connection: (IRCConnection*)connection
  didReceiveMessage: (OFString*)msg
	   fromUser: (IRCUser*)user
	  inChannel: (IRCChannel*)channel;
-	  (void)connection: (IRCConnection*)connection
  didReceivePrivateMessage: (OFString*)msg
		  fromUser: (IRCUser*)user;
- (void)connection: (IRCConnection*)connection
  didReceiveNotice: (OFString*)notice
	  fromUser: (IRCUser*)user;
- (void)connection: (IRCConnection*)connection
  didReceiveNotice: (OFString*)notice
	  fromUser: (IRCUser*)user
	 inChannel: (IRCChannel*)channel;
-	   (void)connection: (IRCConnection*)connection
  didReceiveNamesForChannel: (IRCChannel*)channel;
- (void)connectionWasClosed: (IRCConnection*)connection;
@end

@interface IRCConnection: OFObject
{
	OFTCPSocket *sock;
	OFString *server;
	uint16_t port;
	OFString *nickname, *username, *realname;
	OFMutableDictionary *channels;
	id <IRCConnectionDelegate, OFObject> delegate;
}

@property (copy) OFString *server;
@property (assign) uint16_t port;
@property (copy) OFString *nickname, *username, *realname;
@property (assign) id <IRCConnectionDelegate, OFObject> delegate;
@property (retain, getter=socket) OFTCPSocket *sock;

- (void)sendLine: (OFString*)line;
- (void)sendLineWithFormat: (OFConstantString*)line, ...;
- (void)connect;
- (void)disconnect;
- (void)disconnectWithReason: (OFString*)reason;
- (void)joinChannel: (OFString*)channelName;
- (void)leaveChannel: (IRCChannel*)channel;
- (void)leaveChannel: (IRCChannel*)channel
	  withReason: (OFString*)reason;
- (void)sendMessage: (OFString*)msg
	  toChannel: (IRCChannel*)channel;
- (void)sendMessage: (OFString*)msg
	     toUser: (OFString*)user;
- (void)sendNotice: (OFString*)notice
	    toUser: (OFString*)user;
- (void)sendNotice: (OFString*)notice
	 toChannel: (IRCChannel*)channel;
- (void)kickUser: (OFString*)user
     fromChannel: (IRCChannel*)channel
      withReason: (OFString*)reason;
- (void)changeNicknameTo: (OFString*)nickname;
- (void)process;
- (void)handleConnection;
@end
