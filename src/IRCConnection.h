/*
 * Copyright (c) 2010, 2011, Jonathan Schleifer <js@webkeks.org>
 *
 * https://webkeks.org/hg/objirc/
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
- (void)connection: (IRCConnection*)conn
    didReceiveLine: (OFString*)line;
- (void)connection: (IRCConnection*)conn
       didSendLine: (OFString*)line;
- (void)connectionWasEstablished: (IRCConnection*)conn;
- (void)connection: (IRCConnection*)conn
	didSeeUser: (IRCUser*)user
       joinChannel: (IRCChannel*)channel;
-  (void)connection: (IRCConnection*)conn
  didReceiveMessage: (OFString*)msg
	   fromUser: (IRCUser*)user
	  inChannel: (IRCChannel*)channel;
-	  (void)connection: (IRCConnection*)conn
  didReceivePrivateMessage: (OFString*)msg
		  fromUser: (IRCUser*)user;
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
@property (retain) id <IRCConnectionDelegate, OFObject> delegate;

- (void)connect;
- (void)disconnect;
- (void)disconnectWithReason: (OFString*)reason;
- (void)joinChannel: (OFString*)channelName;
- (void)leaveChannel: (IRCChannel*)channel;
- (void)leaveChannel: (IRCChannel*)channel
	  withReason: (OFString*)reason;
- (void)sendLine: (OFString*)line;
- (void)sendLineWithFormat: (OFConstantString*)line, ...;
- (void)handleConnection;
@end
