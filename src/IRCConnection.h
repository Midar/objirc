/*
 * Copyright (c) 2010, 2011, 2012, 2013, 2016
 *   Jonathan Schleifer <js@heap.zone>
 *
 * https://heap.zone/git/?p=objirc.git
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

#import <ObjFW/ObjFW.h>

@class IRCConnection;
@class IRCUser;

@protocol IRCConnectionDelegate <OFObject>
@optional
- (void)connection: (IRCConnection *)connection
   didCreateSocket: (OF_KINDOF(OFTCPSocket) *)socket;
- (void)connection: (IRCConnection *)connection
    didReceiveLine: (OFString *)line;
- (void)connection: (IRCConnection *)connection
       didSendLine: (OFString *)line;
- (void)connectionWasEstablished: (IRCConnection *)connection;
- (void)connection: (IRCConnection *)connection
	didSeeUser: (IRCUser *)user
       joinChannel: (OFString *)channel;
- (void)connection: (IRCConnection *)connection
	didSeeUser: (IRCUser *)user
      leaveChannel: (OFString *)channel
	    reason: (OFString *)reason;
- (void)connection: (IRCConnection *)connection
        didSeeUser: (IRCUser *)user
  changeNicknameTo: (OFString *)nickname;
- (void)connection: (IRCConnection *)connection
	didSeeUser: (IRCUser *)user
	  kickUser: (OFString *)kickedUser
	   channel: (OFString *)channel
	    reason: (OFString *)reason;
- (void)connection: (IRCConnection *)connection
    didSeeUserQuit: (IRCUser *)user
	    reason: (OFString *)reason;
-  (void)connection: (IRCConnection *)connection
  didReceiveMessage: (OFString *)msg
	    channel: (OFString *)channel
	       user: (IRCUser *)user;
-	  (void)connection: (IRCConnection *)connection
  didReceivePrivateMessage: (OFString *)msg
		      user: (IRCUser *)user;
- (void)connection: (IRCConnection *)connection
  didReceiveNotice: (OFString *)notice
	      user: (IRCUser *)user;
- (void)connection: (IRCConnection *)connection
  didReceiveNotice: (OFString *)notice
	   channel: (OFString *)channel
	      user: (IRCUser *)user;
-	   (void)connection: (IRCConnection *)connection
  didReceiveNamesForChannel: (OFString *)channel;
- (void)connectionWasClosed: (IRCConnection *)connection;
@end

@interface IRCConnection: OFObject
{
	Class _socketClass;
	OF_KINDOF(OFTCPSocket) *_socket;
	OFString *_server;
	uint16_t _port;
	OFString *_nickname, *_username, *_realname;
	OFMutableDictionary OF_GENERIC(OFString *, OFMutableSet *) *_channels;
	id <IRCConnectionDelegate> _delegate;
	of_string_encoding_t _fallbackEncoding;
	of_time_interval_t _pingInterval, _pingTimeout;
	OFString *_pingData;
	OFTimer *_pingTimer;
}

@property (assign) Class socketClass;
@property (nonatomic, copy) OFString *server;
@property uint16_t port;
@property (nonatomic, copy) OFString *nickname, *username, *realname;
@property (assign) id <IRCConnectionDelegate> delegate;
@property (readonly, nonatomic) OFTCPSocket *socket;
@property of_string_encoding_t fallbackEncoding;
@property of_time_interval_t pingInterval, pingTimeout;

+ (instancetype)connection;
- (void)sendLine: (OFString *)line;
- (void)sendLineWithFormat: (OFConstantString *)line, ...;
- (void)connect;
- (void)disconnect;
- (void)disconnectWithReason: (OFString *)reason;
- (void)joinChannel: (OFString *)channelName;
- (void)leaveChannel: (OFString *)channel;
- (void)leaveChannel: (OFString *)channel
	      reason: (OFString *)reason;
- (void)sendMessage: (OFString *)msg
		 to: (OFString *)to;
- (void)sendNotice: (OFString *)notice
		to: (OFString *)to;
- (void)kickUser: (OFString *)user
	 channel: (OFString *)channel
	  reason: (OFString *)reason;
- (void)changeNicknameTo: (OFString *)nickname;
- (void)processLine: (OFString *)line;
- (void)handleConnection;
- (OFSet OF_GENERIC(OFString *) *)usersInChannel: (OFString *)channel;
@end
